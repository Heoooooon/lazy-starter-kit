import Darwin
import Foundation

struct InstallerProcessResult: Sendable {
  let status: Int32
  let output: String
  let cancelled: Bool
}

final class InstallerProcessSession: @unchecked Sendable {
  private let payload: URL
  private let arguments: [String]
  private let environment: [String: String]
  private let removePayloadAfterRun: Bool
  private let onOutput: @Sendable (String) -> Void
  private let onFinish: @Sendable (InstallerProcessResult) -> Void
  private let queue = DispatchQueue(label: "dev.cmore.lazy-starter-kit.installer-process")

  private var pid: pid_t?
  private var readDescriptor: Int32 = -1
  private var readSource: DispatchSourceRead?
  private var exitSource: DispatchSourceProcess?
  private var captured = Data()
  private var exitStatus: Int32?
  private var reachedEOF = false
  private var cancelled = false
  private var cancellationEscalated = false
  private var escalationScheduled = false
  private var finished = false

  init(
    payload: URL,
    arguments: [String],
    environment: [String: String],
    removePayloadAfterRun: Bool,
    onOutput: @escaping @Sendable (String) -> Void,
    onFinish: @escaping @Sendable (InstallerProcessResult) -> Void
  ) {
    self.payload = payload
    self.arguments = arguments
    self.environment = environment
    self.removePayloadAfterRun = removePayloadAfterRun
    self.onOutput = onOutput
    self.onFinish = onFinish
  }

  func start() throws {
    if queue.sync(execute: { cancelled }) {
      if removePayloadAfterRun { try? FileManager.default.removeItem(at: payload) }
      onFinish(InstallerProcessResult(status: 130, output: "", cancelled: true))
      return
    }
    var descriptors = [Int32](repeating: -1, count: 2)
    guard pipe(&descriptors) == 0 else { throw posixError(errno) }
    let readFD = descriptors[0]
    let writeFD = descriptors[1]

    var fileActions: posix_spawn_file_actions_t?
    var attributes: posix_spawnattr_t?
    guard posix_spawn_file_actions_init(&fileActions) == 0 else {
      close(readFD)
      close(writeFD)
      throw posixError(errno)
    }
    defer { posix_spawn_file_actions_destroy(&fileActions) }
    guard posix_spawnattr_init(&attributes) == 0 else {
      close(readFD)
      close(writeFD)
      throw posixError(errno)
    }
    defer { posix_spawnattr_destroy(&attributes) }

    posix_spawn_file_actions_adddup2(&fileActions, writeFD, STDOUT_FILENO)
    posix_spawn_file_actions_adddup2(&fileActions, writeFD, STDERR_FILENO)
    posix_spawn_file_actions_addclose(&fileActions, readFD)
    posix_spawn_file_actions_addclose(&fileActions, writeFD)
    posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))
    posix_spawnattr_setpgroup(&attributes, 0)

    let command = ["/bin/bash", payload.path] + arguments
    var argv = command.map { strdup($0) } + [nil]
    defer { argv.compactMap { $0 }.forEach { free($0) } }
    var environmentValues = environment.map { "\($0.key)=\($0.value)" }
    environmentValues.sort()
    var envp = environmentValues.map { strdup($0) } + [nil]
    defer { envp.compactMap { $0 }.forEach { free($0) } }

    var childPID: pid_t = 0
    let result = posix_spawn(
      &childPID,
      "/bin/bash",
      &fileActions,
      &attributes,
      &argv,
      &envp
    )
    close(writeFD)
    guard result == 0 else {
      close(readFD)
      if removePayloadAfterRun { try? FileManager.default.removeItem(at: payload) }
      throw posixError(result)
    }

    let flags = fcntl(readFD, F_GETFL)
    if flags >= 0 { _ = fcntl(readFD, F_SETFL, flags | O_NONBLOCK) }

    queue.sync {
      pid = childPID
      readDescriptor = readFD

      let outputSource = DispatchSource.makeReadSource(fileDescriptor: readFD, queue: queue)
      outputSource.setEventHandler { [weak self] in self?.drainOutput() }
      readSource = outputSource
      outputSource.resume()

      let processSource = DispatchSource.makeProcessSource(
        identifier: childPID,
        eventMask: .exit,
        queue: queue
      )
      processSource.setEventHandler { [weak self] in self?.recordExit() }
      exitSource = processSource
      processSource.resume()
      if cancelled {
        terminateProcessGroup(childPID)
      }
    }
  }

  func cancel() {
    queue.async { [weak self] in
      guard let self, !self.finished else { return }
      self.cancelled = true
      guard let pid = self.pid else { return }
      self.terminateProcessGroup(pid)
    }
  }

  private func drainOutput() {
    guard readDescriptor >= 0 else { return }
    var buffer = [UInt8](repeating: 0, count: 65_536)
    while true {
      let count = buffer.withUnsafeMutableBytes {
        Darwin.read(readDescriptor, $0.baseAddress, $0.count)
      }
      if count > 0 {
        let data = Data(buffer.prefix(count))
        captured.append(data)
        onOutput(String(decoding: data, as: UTF8.self))
      } else if count == 0 {
        reachedEOF = true
        readSource?.cancel()
        readSource = nil
        completeIfReady(forceDrain: false)
        return
      } else if errno == EAGAIN || errno == EWOULDBLOCK {
        return
      } else {
        reachedEOF = true
        readSource?.cancel()
        readSource = nil
        completeIfReady(forceDrain: false)
        return
      }
    }
  }

  private func recordExit() {
    guard let pid, exitStatus == nil else { return }
    var rawStatus: Int32 = 0
    if waitpid(pid, &rawStatus, 0) == pid {
      let signal = rawStatus & 0x7f
      exitStatus = signal == 0 ? ((rawStatus >> 8) & 0xff) : (128 + signal)
    } else {
      exitStatus = 1
    }
    exitSource?.cancel()
    exitSource = nil
    completeIfReady(forceDrain: false)
    queue.asyncAfter(deadline: .now() + 0.75) { [weak self] in
      self?.completeIfReady(forceDrain: true)
    }
  }

  private func completeIfReady(forceDrain: Bool) {
    guard !finished, let status = exitStatus, reachedEOF || forceDrain else { return }
    if
      cancelled,
      !cancellationEscalated,
      let pid,
      Darwin.kill(-pid, 0) == 0
    {
      return
    }
    finished = true
    readSource?.cancel()
    readSource = nil
    if readDescriptor >= 0 {
      close(readDescriptor)
      readDescriptor = -1
    }
    if removePayloadAfterRun { try? FileManager.default.removeItem(at: payload) }
    onFinish(
      InstallerProcessResult(
        status: cancelled ? 130 : status,
        output: String(decoding: captured, as: UTF8.self),
        cancelled: cancelled
      )
    )
  }

  private func terminateProcessGroup(_ pid: pid_t) {
    _ = Darwin.kill(-pid, SIGTERM)
    guard !escalationScheduled else { return }
    escalationScheduled = true
    queue.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      guard let self else { return }
      guard !self.finished else { return }
      _ = Darwin.kill(-pid, SIGKILL)
      self.cancellationEscalated = true
      self.completeIfReady(forceDrain: true)
    }
  }

  private func posixError(_ code: Int32) -> NSError {
    NSError(domain: NSPOSIXErrorDomain, code: Int(code))
  }
}
