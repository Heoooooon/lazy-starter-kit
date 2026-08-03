import AppKit
import Foundation

private let profiles = ["full", "minimal", "work"]
private let defaultInstallerURL =
  "https://raw.githubusercontent.com/Heoooooon/lazy-starter-kit/main/install.sh"

private func selfTest() {
  let contract: [String: Any] = [
    "profiles": profiles,
    "supportsDryRun": true,
    "installerURL": defaultInstallerURL,
  ]
  let data = try! JSONSerialization.data(withJSONObject: contract, options: [.sortedKeys])
  print(String(decoding: data, as: UTF8.self))
}

@MainActor
private final class InstallerController: NSObject, NSApplicationDelegate {
  private let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 720, height: 600),
    styleMask: [.titled, .closable, .miniaturizable],
    backing: .buffered,
    defer: false
  )
  private let profile = NSPopUpButton(frame: .zero, pullsDown: false)
  private let dryRun = NSButton(checkboxWithTitle: "설치 전 변경 내용을 미리 보기", target: nil, action: nil)
  private let installButton = NSButton(title: "설치 시작", target: nil, action: nil)
  private let status = NSTextField(labelWithString: "준비됨")
  private let log = NSTextView()
  private var task: Process?

  func applicationDidFinishLaunching(_ notification: Notification) {
    buildUI()
    window.center()
    window.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
    if ProcessInfo.processInfo.environment["STARTER_KIT_GUI_AUTOSTART"] == "1" {
      DispatchQueue.main.async { [weak self] in self?.startInstall() }
    }
  }

  private func buildUI() {
    window.title = "Lazy Starter Kit Installer"
    window.isReleasedWhenClosed = false
    window.backgroundColor = NSColor.windowBackgroundColor

    let title = NSTextField(labelWithString: "AI 코딩 환경을 쉽게 설치하세요")
    title.font = .systemFont(ofSize: 26, weight: .bold)
    let subtitle = NSTextField(
      wrappingLabelWithString:
        "터미널 명령어를 입력할 필요가 없습니다. 설치 범위를 고른 뒤 버튼만 누르세요."
    )
    subtitle.textColor = .secondaryLabelColor
    subtitle.font = .systemFont(ofSize: 14)

    let profileLabel = NSTextField(labelWithString: "설치 범위")
    profileLabel.font = .systemFont(ofSize: 13, weight: .semibold)
    profile.addItems(withTitles: ["전체 설치", "최소 설치", "회사 PC용"])
    profile.toolTip = "전체 · 최소 · Docker를 제외한 회사 PC용 중에서 선택합니다."

    dryRun.state = .on
    dryRun.toolTip = "처음에는 컴퓨터를 바꾸지 않고 설치 계획만 보여줍니다."
    installButton.bezelStyle = .rounded
    installButton.keyEquivalent = "\r"
    installButton.target = self
    installButton.action = #selector(startInstall)

    status.font = .systemFont(ofSize: 13, weight: .medium)
    status.textColor = .secondaryLabelColor

    log.isEditable = false
    log.isSelectable = true
    log.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    log.backgroundColor = NSColor.textBackgroundColor
    log.textContainerInset = NSSize(width: 10, height: 10)
    log.string = """
      준비가 되었습니다.

      처음이라면 ‘설치 전 변경 내용을 미리 보기’를 켠 채 시작하세요.
      미리보기가 끝나면 체크를 끄고 다시 눌러 실제 설치를 진행할 수 있습니다.
      """
    let scroll = NSScrollView()
    scroll.documentView = log
    scroll.hasVerticalScroller = true
    scroll.borderType = .bezelBorder

    let controls = NSStackView(views: [profileLabel, profile, dryRun, installButton])
    controls.orientation = .horizontal
    controls.alignment = .centerY
    controls.spacing = 12
    profile.setContentHuggingPriority(.defaultLow, for: .horizontal)

    let content = NSStackView(views: [title, subtitle, controls, status, scroll])
    content.orientation = .vertical
    content.alignment = .leading
    content.spacing = 14
    content.edgeInsets = NSEdgeInsets(top: 28, left: 30, bottom: 28, right: 30)
    content.translatesAutoresizingMaskIntoConstraints = false
    window.contentView = content
    scroll.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      content.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
      content.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
      content.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
      content.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
      subtitle.widthAnchor.constraint(equalTo: content.widthAnchor, constant: -60),
      controls.widthAnchor.constraint(equalTo: content.widthAnchor, constant: -60),
      scroll.widthAnchor.constraint(equalTo: content.widthAnchor, constant: -60),
      scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 360),
    ])
  }

  @objc private func startInstall() {
    guard task == nil else { return }
    installButton.isEnabled = false
    profile.isEnabled = false
    dryRun.isEnabled = false
    status.stringValue = "설치 파일을 내려받는 중…"
    log.string = ""

    let selectedProfile = profiles[profile.indexOfSelectedItem]
    let preview = dryRun.state == .on
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      self?.downloadAndRun(profile: selectedProfile, dryRun: preview)
    }
  }

  nonisolated private func downloadAndRun(profile: String, dryRun: Bool) {
    let envURL = ProcessInfo.processInfo.environment["STARTER_KIT_INSTALL_URL"]
    guard let url = URL(string: envURL ?? defaultInstallerURL) else {
      finish(code: 1, message: "설치 주소가 올바르지 않습니다.")
      return
    }
    do {
      let data = try Data(contentsOf: url)
      let payload = FileManager.default.temporaryDirectory
        .appendingPathComponent("lazy-starter-kit-\(UUID().uuidString).sh")
      try data.write(to: payload, options: .atomic)
      run(payload: payload, profile: profile, dryRun: dryRun)
    } catch {
      finish(code: 1, message: "설치 파일 다운로드 실패: \(error.localizedDescription)")
    }
  }

  nonisolated private func run(payload: URL, profile: String, dryRun: Bool) {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [payload.path, "--yes", "--profile", profile] + (dryRun ? ["--dry-run"] : [])
    process.standardOutput = output
    process.standardError = output

    output.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      let text = String(decoding: data, as: UTF8.self)
      Task { @MainActor in self?.appendLog(text) }
    }
    process.terminationHandler = { [weak self] completed in
      output.fileHandleForReading.readabilityHandler = nil
      try? FileManager.default.removeItem(at: payload)
      self?.finish(
        code: completed.terminationStatus,
        message: completed.terminationStatus == 0
          ? (dryRun ? "미리보기가 끝났습니다." : "설치가 끝났습니다.")
          : "설치가 완료되지 않았습니다. 아래 로그를 확인해 주세요."
      )
    }

    Task { @MainActor in
      self.task = process
      self.status.stringValue = dryRun ? "변경 내용을 미리 보는 중…" : "설치 중… 창을 닫지 마세요."
    }
    do {
      try process.run()
    } catch {
      try? FileManager.default.removeItem(at: payload)
      finish(code: 1, message: "설치기를 시작하지 못했습니다: \(error.localizedDescription)")
    }
  }

  @MainActor private func appendLog(_ text: String) {
    log.textStorage?.append(NSAttributedString(string: text))
    log.scrollToEndOfDocument(nil)
  }

  nonisolated private func finish(code: Int32, message: String) {
    Task { @MainActor in
      self.task = nil
      self.status.stringValue = message
      self.status.textColor = code == 0 ? .systemGreen : .systemRed
      self.installButton.title =
        self.dryRun.state == .on && code == 0 ? "실제 설치 시작" : "다시 실행"
      if self.dryRun.state == .on && code == 0 { self.dryRun.state = .off }
      self.installButton.isEnabled = true
      self.profile.isEnabled = true
      self.dryRun.isEnabled = true
      let environment = ProcessInfo.processInfo.environment
      if let resultPath = environment["STARTER_KIT_GUI_RESULT"] {
        do {
          try "\(code)\n\(message)\n".write(
            toFile: resultPath,
            atomically: true,
            encoding: .utf8
          )
        } catch {
          self.appendLog("\nQA completion signal failed: \(error.localizedDescription)\n")
        }
      }
      if environment["STARTER_KIT_GUI_EXIT_ON_FINISH"] == "1" {
        NSApplication.shared.terminate(nil)
      }
    }
  }

  func saveSnapshot(to path: String) throws {
    buildUI()
    window.center()
    window.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
    window.contentView?.layoutSubtreeIfNeeded()
    window.displayIfNeeded()
    guard
      let view = window.contentView,
      let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)
    else { throw CocoaError(.fileWriteUnknown) }
    view.cacheDisplay(in: view.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
      throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: URL(fileURLWithPath: path), options: .atomic)
  }
}

let arguments = CommandLine.arguments
if arguments.contains("--self-test") {
  selfTest()
} else {
  MainActor.assumeIsolated {
    let app = NSApplication.shared
    let controller = InstallerController()
    if let index = arguments.firstIndex(of: "--snapshot"), index + 1 < arguments.count {
      do {
        try controller.saveSnapshot(to: arguments[index + 1])
      } catch {
        fputs("snapshot failed: \(error.localizedDescription)\n", stderr)
        exit(1)
      }
    } else {
      app.delegate = controller
      app.run()
    }
  }
}
