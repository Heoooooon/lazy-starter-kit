import AppKit
import CryptoKit
import Foundation

private struct InstallerProfile {
  let id: String
  let title: String
  let steps: [String]
}

private let profilePlans = [
  InstallerProfile(
    id: "ai",
    title: "AI 코딩 시작 — 추천",
    steps: ["prereqs", "brew", "runtimes", "shell", "git", "agents"]
  ),

  InstallerProfile(
    id: "recommended",
    title: "고급 · 개발 도구 추천",
    steps: ["prereqs", "brew", "runtimes", "shell", "git", "agents"]
  ),
  InstallerProfile(
    id: "full",
    title: "고급 · 전체 설치",
    steps: ["prereqs", "brew", "runtimes", "shell", "docker", "git", "agents"]
  ),
  InstallerProfile(
    id: "minimal",
    title: "고급 · 최소 설치",
    steps: ["prereqs", "brew", "runtimes", "shell", "git"]
  ),
  InstallerProfile(
    id: "work",
    title: "고급 · 회사 PC용",
    steps: ["prereqs", "brew", "runtimes", "shell", "git", "agents"]
  ),
]
private let profiles = profilePlans.map(\.id)
private let toolsURL = "https://cmore.dev/lazy-starter-kit/tools/"
private let releasesURL = "https://github.com/Heoooooon/lazy-starter-kit/releases/latest"
private let canonicalRepositoryURL = "https://github.com/Heoooooon/lazy-starter-kit.git"
private let previewActionTitle = "미리보기 시작"
private let installActionTitle = "설치 시작"

private func primaryActionTitle(preview: Bool) -> String {
  preview ? previewActionTitle : installActionTitle
}

private enum CompletionAction: String {
  case administratorRequired = "administrator-required"
  case cancelled
  case openNewTerminal = "open-new-terminal"
  case firstRun = "first-run"
  case actionNeeded = "action-needed"
  case retry
  case startInstall = "start-install"
  case terminalRequired = "terminal-required"
}

private enum PermissionGuidance: String {
  case adminAccountRequiredNoPassword = "admin-account-required-no-password"
  case terminalApprovalRequiredNoPassword = "terminal-approval-required-no-password"
}

private enum AdministratorStatus {
  case administrator
  case standardUser
  case unavailable(String)
}

private enum PrerequisiteStatus {
  case missingBoth
  case missingHomebrew
  case missingXcode
  case ready

  var description: String {
    switch self {
    case .missingBoth:
      "Xcode Command Line Tools와 Homebrew"
    case .missingHomebrew:
      "Homebrew"
    case .missingXcode:
      "Xcode Command Line Tools"
    case .ready:
      ""
    }
  }
}

private enum InstallerError: LocalizedError {
  case bundledInstallerMissing
  case installerIntegrityFailed
  case installerInvalid
  case terminalOpenFailed

  var errorDescription: String? {
    switch self {
    case .bundledInstallerMissing:
      "앱에 포함된 설치 파일을 찾지 못했습니다."
    case .installerIntegrityFailed:
      "앱에 포함된 설치 파일의 무결성 확인에 실패했습니다."
    case .installerInvalid:
      "설치 파일 형식이 올바르지 않습니다."
    case .terminalOpenFailed:
      "Terminal을 열지 못했습니다."
    }
  }
}

private struct AIReadinessReport: Decodable {
  struct Summary: Decodable { let missing: Int; let pathOnly: Int }
  struct Item: Decodable { let id: String; let state: String }
  let summary: Summary
  let items: [Item]
}

private struct InstallerPayload {
  let url: URL
  let removeAfterRun: Bool
}

private func sha256Hex(_ data: Data) -> String {
  SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func validatedInstallerData(from url: URL, expectedSHA256: String) throws -> Data {
  let data = try Data(contentsOf: url)
  guard data.starts(with: Data("#!/usr/bin/env bash".utf8)) else {
    throw InstallerError.installerInvalid
  }
  guard expectedSHA256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
    throw InstallerError.installerInvalid
  }
  if sha256Hex(data) != expectedSHA256 {
    throw InstallerError.installerIntegrityFailed
  }
  return data
}

private func resolveInstallerPayload() throws -> InstallerPayload {
  if let override = ProcessInfo.processInfo.environment["STARTER_KIT_INSTALL_URL"] {
    guard BuildInfo.developerMode else { throw InstallerError.installerInvalid }
    guard let url = URL(string: override) else { throw InstallerError.installerInvalid }
    guard
      let expectedSHA256 = ProcessInfo.processInfo.environment["STARTER_KIT_INSTALL_SHA256"]
    else {
      throw InstallerError.installerIntegrityFailed
    }
    let data = try validatedInstallerData(from: url, expectedSHA256: expectedSHA256)
    let payload = FileManager.default.temporaryDirectory
      .appendingPathComponent("lazy-starter-kit-\(UUID().uuidString).sh")
    try data.write(to: payload, options: .atomic)
    return InstallerPayload(url: payload, removeAfterRun: true)
  }
  guard let bundled = Bundle.main.url(forResource: "install", withExtension: "sh") else {
    throw InstallerError.bundledInstallerMissing
  }
  _ = try validatedInstallerData(from: bundled, expectedSHA256: BuildInfo.installerSHA256)
  return InstallerPayload(url: bundled, removeAfterRun: false)
}

private func installerEnvironment() -> [String: String] {
  let inherited = ProcessInfo.processInfo.environment
  var environment = BuildInfo.developerMode
    ? inherited
    : inherited.filter { !$0.key.hasPrefix("STARTER_KIT_") }
  environment["STARTER_KIT_BRANCH"] = BuildInfo.releaseRef
  environment["STARTER_KIT_COMMIT"] = BuildInfo.releaseCommit
  environment["STARTER_KIT_REPO"] = canonicalRepositoryURL
  let cloneDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("lazy-starter-kit-\(UUID().uuidString)")
    .path
  environment["STARTER_KIT_DIR"] = cloneDirectory
  environment["STARTER_KIT_EPHEMERAL_ROOT"] = cloneDirectory
  return environment
}

private func administratorStatus() -> AdministratorStatus {
  if
    BuildInfo.developerMode,
    let override = ProcessInfo.processInfo.environment["STARTER_KIT_GUI_ADMIN_STATUS"]
  {
    return override == "1" ? .administrator : .standardUser
  }

  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/dsmemberutil")
  process.arguments = ["checkmembership", "-U", NSUserName(), "-G", "admin"]
  process.standardOutput = FileHandle.nullDevice
  process.standardError = FileHandle.nullDevice
  do {
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus == 0 ? .administrator : .standardUser
  } catch {
    return .unavailable(error.localizedDescription)
  }
}

private func prerequisiteStatus() -> PrerequisiteStatus {
  if
    BuildInfo.developerMode,
    let override = ProcessInfo.processInfo.environment["STARTER_KIT_GUI_PREREQUISITES"]
  {
    switch override {
    case "missing-both":
      return .missingBoth
    case "missing-homebrew":
      return .missingHomebrew
    case "missing-xcode":
      return .missingXcode
    case "ready":
      return .ready
    default:
      break
    }
  }

  let xcode = Process()
  xcode.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
  xcode.arguments = ["-p"]
  xcode.standardOutput = FileHandle.nullDevice
  xcode.standardError = FileHandle.nullDevice
  let hasXcode: Bool
  do {
    try xcode.run()
    xcode.waitUntilExit()
    hasXcode = xcode.terminationStatus == 0
  } catch {
    hasXcode = false
  }

  let fileManager = FileManager.default
  let hasHomebrew =
    fileManager.isExecutableFile(atPath: "/opt/homebrew/bin/brew")
    || fileManager.isExecutableFile(atPath: "/usr/local/bin/brew")
  switch (hasXcode, hasHomebrew) {
  case (true, true):
    return .ready
  case (true, false):
    return .missingHomebrew
  case (false, true):
    return .missingXcode
  case (false, false):
    return .missingBoth
  }
}

private func selfTest() {
  let profileSteps = Dictionary(
    uniqueKeysWithValues: profilePlans.map { ($0.id, $0.steps) }
  )
  let contract: [String: Any] = [
    "hasApplicationIcon": true,
    "interfaceVersion": 5,
    "previewIsSecondaryAction": true,
    "profiles": profiles,
    "defaultProfile": profilePlans[0].id,
    "profileSteps": profileSteps,
    "supportsAppearanceSnapshots": true,
    "supportsCustomSelection": true,
    "supportsCancellation": true,
    "supportsDryRun": true,
    "supportsRepeatApply": true,
    "actionTitlesTrackPreviewState":
      primaryActionTitle(preview: true) != primaryActionTitle(preview: false),
    "appVersion": BuildInfo.appVersion,
    "developerMode": BuildInfo.developerMode,
    "installActionTitle": installActionTitle,
    "installerSHA256": BuildInfo.installerSHA256,
    "installerSource": "bundled",
    "previewActionTitle": previewActionTitle,
    "releaseCommit": BuildInfo.releaseCommit,
    "releaseRef": BuildInfo.releaseRef,
    "releasesURL": releasesURL,
    "toolsURL": toolsURL,
  ]
  let data = try! JSONSerialization.data(withJSONObject: contract, options: [.sortedKeys])
  print(String(decoding: data, as: UTF8.self))
}

@MainActor
private func installMainMenu(for app: NSApplication) {
  let mainMenu = NSMenu()
  let appMenuItem = NSMenuItem()
  mainMenu.addItem(appMenuItem)
  let appMenu = NSMenu()
  appMenu.addItem(
    withTitle: "Lazy Starter Kit Installer 종료",
    action: #selector(NSApplication.terminate(_:)),
    keyEquivalent: "q"
  )
  appMenuItem.submenu = appMenu
  app.mainMenu = mainMenu
}

@MainActor
private final class InstallerController: NSObject, NSApplicationDelegate, NSWindowDelegate {
  private let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 760, height: 800),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
  )
  private let profile = NSPopUpButton(frame: .zero, pullsDown: false)
  private let profileDetails = NSTextField(wrappingLabelWithString: "")
  private let coreChoice = NSButton(checkboxWithTitle: "기본 도구", target: nil, action: nil)
  private let runtimesChoice = NSButton(
    checkboxWithTitle: "언어 런타임",
    target: nil,
    action: nil
  )
  private let dockerChoice = NSButton(checkboxWithTitle: "Docker", target: nil, action: nil)
  private let agentsChoice = NSButton(
    checkboxWithTitle: "AI 에이전트",
    target: nil,
    action: nil
  )
  private let dryRun = NSButton(checkboxWithTitle: "먼저 미리보기", target: nil, action: nil)
  private let installButton = NSButton(title: installActionTitle, target: nil, action: nil)
  private let previewButton = NSButton(title: previewActionTitle, target: nil, action: nil)
  private let agentChoice = NSPopUpButton(frame: .zero, pullsDown: false)
  private let launchButton = NSButton(title: "연습 폴더에서 시작", target: nil, action: nil)
  private let copyButton = NSButton(title: "시작 프롬프트 복사", target: nil, action: nil)
  private let checkButton = NSButton(title: "설치 결과 확인", target: nil, action: nil)
  private let starterPrompt = "이 빈 연습 폴더에서 간단한 자기소개 웹페이지를 만들어 주세요. 먼저 계획을 설명하고, 이 폴더 밖의 파일은 변경하지 마세요. 각 단계에서 무엇을 하는지 초보자에게 설명해 주세요."
  private lazy var promptPasteboard: NSPasteboard =
    BuildInfo.developerMode && ProcessInfo.processInfo.environment["STARTER_KIT_GUI_COPY_PROMPT"] == "1"
      ? NSPasteboard.withUniqueName() : NSPasteboard.general
  private let logsToggle = NSButton(title: "상세 로그 보기", target: nil, action: nil)
  private var logViewportView: NSView?
  private var practiceFolder: URL?
  private var practiceCommand: URL?
  private var firstRunView: NSView?
  private var setupHeight: NSLayoutConstraint?
  private var runWasAI = false
  private let cancelButton = NSButton(title: "설치 취소", target: nil, action: nil)
  private let statusIcon = NSImageView()
  private let status = NSTextField(wrappingLabelWithString: "준비됨")
  private let log = NSTextField()
  private let logScroll = NSScrollView()
  private let logEmptyState = NSTextField(
    wrappingLabelWithString:
      "실행 명령과 문제 해결에 필요한 상세 내용이 여기에 표시됩니다."
  )
  private var session: InstallerProcessSession?
  private var isPreparing = false
  private var preparationCancelled = false
  private var completedActionTitle: String?
  private var terminateAfterCancellation = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.applicationIconImage = Brand.appIcon(size: 512)
    buildUI()
    let environment = BuildInfo.developerMode
      ? ProcessInfo.processInfo.environment
      : [:]
    window.center()
    window.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
    guard BuildInfo.developerMode else { return }
    if let readyPath = environment["STARTER_KIT_GUI_WINDOW_READY"] {
      do {
        try "window-ready\n".write(
          toFile: readyPath,
          atomically: true,
          encoding: .utf8
        )
      } catch {
        fputs("window-ready signal failed: \(error.localizedDescription)\n", stderr)
        exit(1)
      }
      NSApplication.shared.terminate(nil)
      return
    }
    if
      let profileID = environment["STARTER_KIT_GUI_PROFILE"],
      let index = profilePlans.firstIndex(where: { $0.id == profileID })
    {
      profile.selectItem(at: index)
      applyProfilePlan(profilePlans[index])
    }
    if environment["STARTER_KIT_GUI_AUTOSTART"] == "1" {
      DispatchQueue.main.async { [weak self] in
        if environment["STARTER_KIT_GUI_CHECK_RESULT"] == "1" {
          self?.checkInstallation()
        } else if environment["STARTER_KIT_GUI_DRY_RUN"] == "1" {
          self?.startPreview()
        } else {
          self?.startInstall()
        }
      }
    }

  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    window.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
    return true
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard session != nil || isPreparing else { return .terminateNow }
    terminateAfterCancellation = true
    cancelInstall()
    return .terminateCancel
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    session == nil && !isPreparing
  }

  private func buildUI() {
    window.title = "Lazy Starter Kit Installer"
    window.delegate = self
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 700, height: 742)
    window.backgroundColor = NSColor.windowBackgroundColor

    let brandIcon = NSImageView(image: Brand.appIcon(size: 64))
    brandIcon.imageScaling = .scaleProportionallyUpOrDown
    brandIcon.setAccessibilityLabel("Lazy Starter Kit")
    NSLayoutConstraint.activate([
      brandIcon.widthAnchor.constraint(equalToConstant: 64),
      brandIcon.heightAnchor.constraint(equalToConstant: 64),
    ])

    let eyebrow = NSTextField(labelWithString: "LAZY STARTER KIT")
    eyebrow.font = .systemFont(ofSize: 11, weight: .semibold)
    eyebrow.textColor = .secondaryLabelColor

    let title = NSTextField(labelWithString: "한 줄이면, 바로 시작.")
    title.font = .systemFont(ofSize: 28, weight: .bold)
    let subtitle = NSTextField(
      wrappingLabelWithString:
        "AI 코딩에 필요한 도구를 준비합니다. 계정 로그인은 설치 후 직접 진행하세요."
    )
    subtitle.textColor = .secondaryLabelColor
    subtitle.font = .systemFont(ofSize: 14)
    let titleStack = NSStackView(views: [eyebrow, title, subtitle])
    titleStack.orientation = .vertical
    titleStack.alignment = .leading
    titleStack.spacing = 5
    let header = NSStackView(views: [brandIcon, titleStack])
    header.orientation = .horizontal
    header.alignment = .centerY
    header.spacing = 16

    let profileImage = NSImageView(
      image: NSImage(
        systemSymbolName: "slider.horizontal.3",
        accessibilityDescription: "설치 구성"
      ) ?? NSImage()
    )
    profileImage.contentTintColor = .secondaryLabelColor
    let profileLabel = NSTextField(labelWithString: "설치 구성")
    profileLabel.font = .systemFont(ofSize: 13, weight: .semibold)
    let profileHeader = NSStackView(views: [profileImage, profileLabel])
    profileHeader.orientation = .horizontal
    profileHeader.alignment = .centerY
    profileHeader.spacing = 7

    profile.addItems(withTitles: profilePlans.map(\.title) + ["사용자 지정"])
    profile.selectItem(at: 0)
    profile.toolTip = "구성을 선택하면 실제 설치 도구와 적용 단계를 아래에서 확인할 수 있습니다."
    profile.controlSize = .large
    profile.setContentHuggingPriority(NSLayoutConstraint.Priority(200), for: .horizontal)
    profile.target = self
    profile.action = #selector(profileDidChange)

    profileDetails.font = .systemFont(ofSize: 11)
    profileDetails.textColor = .secondaryLabelColor
    profileDetails.maximumNumberOfLines = 0
    profileDetails.setAccessibilityLabel("선택한 설치 구성 상세")

    coreChoice.state = .on
    coreChoice.isEnabled = false
    coreChoice.toolTip = "Xcode CLT, Homebrew, Git, 셸과 기본 터미널 도구"
    for choice in [runtimesChoice, dockerChoice, agentsChoice] {
      choice.target = self
      choice.action = #selector(componentDidChange(_:))
    }
    runtimesChoice.toolTip = "Node.js, Python, Go, Rust와 버전 관리자"
    dockerChoice.toolTip = "Colima, Docker CLI, Compose와 Buildx"
    agentsChoice.toolTip = "Claude Code, Codex"
    applyProfilePlan(profilePlans[0])

    let componentChoices = NSStackView(
      views: [coreChoice, runtimesChoice, dockerChoice, agentsChoice]
    )
    componentChoices.orientation = .horizontal
    componentChoices.alignment = .centerY
    componentChoices.spacing = 14
    let componentSpacer = NSView()
    componentSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    let toolsButton = NSButton(
      title: "cmore.dev 도구 설명 ↗",
      target: self,
      action: #selector(openToolsGuide)
    )
    toolsButton.bezelStyle = .inline
    toolsButton.controlSize = .small
    toolsButton.contentTintColor = Brand.cobalt
    toolsButton.attributedTitle = NSAttributedString(
      string: toolsButton.title,
      attributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
        .foregroundColor: Brand.cobalt,
      ]
    )
    toolsButton.toolTip = toolsURL
    let permissionButton = NSButton(
      title: "관리자 권한이란?",
      target: self,
      action: #selector(openPermissionHelp)
    )
    permissionButton.bezelStyle = .inline
    permissionButton.controlSize = .small
    permissionButton.contentTintColor = Brand.cobalt
    permissionButton.attributedTitle = NSAttributedString(
      string: permissionButton.title,
      attributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
        .foregroundColor: Brand.cobalt,
      ]
    )
    permissionButton.toolTip = "관리자 계정과 비밀번호 처리 방식을 설명합니다."
    let componentRow = NSStackView(views: [componentChoices, componentSpacer])
    componentRow.orientation = .horizontal
    componentRow.alignment = .centerY
    componentRow.spacing = 10
    let helpSpacer = NSView()
    helpSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    let helpRow = NSStackView(views: [helpSpacer, permissionButton, toolsButton])
    helpRow.orientation = .horizontal
    helpRow.alignment = .centerY
    helpRow.spacing = 10

    dryRun.state = .off
    previewButton.bezelStyle = .rounded
    previewButton.controlSize = .large
    previewButton.toolTip = "도구 설치나 연습 폴더 생성 없이 계획만 확인합니다."
    previewButton.target = self
    previewButton.action = #selector(startPreview)
    installButton.bezelStyle = .rounded
    installButton.controlSize = .large
    installButton.image = NSImage(
      systemSymbolName: "arrow.down.circle.fill",
      accessibilityDescription: "설치 시작"
    )
    installButton.imagePosition = .imageLeading
    installButton.keyEquivalent = "\r"
    installButton.target = self
    installButton.action = #selector(startInstall)
    cancelButton.bezelStyle = .rounded
    cancelButton.controlSize = .large
    cancelButton.isHidden = true
    cancelButton.target = self
    cancelButton.action = #selector(cancelInstall)
    NSLayoutConstraint.activate([
      profile.widthAnchor.constraint(greaterThanOrEqualToConstant: 168),
      installButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
      installButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
      cancelButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
    ])

    let controlsSpacer = NSView()
    controlsSpacer.setContentHuggingPriority(
      NSLayoutConstraint.Priority(249),
      for: .horizontal
    )
    controlsSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    let controls = NSStackView(
      views: [profile, controlsSpacer, cancelButton, previewButton, installButton]
    )
    controls.orientation = .horizontal
    controls.alignment = .centerY
    controls.spacing = 14

    let setupHint = NSTextField(
      wrappingLabelWithString:
        "Claude: Anthropic 계정과 이용 가능한 구독 또는 API 결제. Codex: OpenAI 계정과 이용 권한 또는 API 결제가 필요합니다. 서비스 사용료는 별도이며, 로그인과 요청 전송은 자동으로 하지 않습니다."
    )
    setupHint.font = .systemFont(ofSize: 12)
    setupHint.textColor = .secondaryLabelColor
    let setupContent = NSStackView(
      views: [profileHeader, controls, componentRow, helpRow, profileDetails, setupHint]
    )
    setupContent.orientation = .vertical
    setupContent.alignment = .leading
    setupContent.spacing = 11
    NSLayoutConstraint.activate([
      controls.widthAnchor.constraint(equalTo: setupContent.widthAnchor),
      componentRow.widthAnchor.constraint(equalTo: setupContent.widthAnchor),
      helpRow.widthAnchor.constraint(equalTo: setupContent.widthAnchor),
      profileDetails.widthAnchor.constraint(equalTo: setupContent.widthAnchor),
      setupHint.widthAnchor.constraint(equalTo: setupContent.widthAnchor),
    ])
    let setupBox = makeCard(containing: setupContent, inset: 18)
    let setupHeightConstraint = setupBox.heightAnchor.constraint(equalToConstant: 250)
    setupHeightConstraint.isActive = true
    setupHeight = setupHeightConstraint
    setupBox.setContentHuggingPriority(.required, for: .vertical)
    setupBox.setContentCompressionResistancePriority(.required, for: .vertical)

    status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    status.maximumNumberOfLines = 2
    status.font = .systemFont(ofSize: 13, weight: .medium)
    status.textColor = .secondaryLabelColor
    statusIcon.image = NSImage(
      systemSymbolName: "circle.fill",
      accessibilityDescription: "준비"
    )
    statusIcon.contentTintColor = .secondaryLabelColor
    let statusSpacer = NSView()
    let trustIcon = NSImageView(
      image: NSImage(
        systemSymbolName: "checkmark.shield.fill",
        accessibilityDescription: "Developer ID 서명"
      ) ?? NSImage()
    )
    trustIcon.contentTintColor = Brand.mint
    let trustLabel = NSTextField(labelWithString: "로그인 별도")
    trustLabel.font = .systemFont(ofSize: 11, weight: .medium)
    trustLabel.textColor = .secondaryLabelColor
    let versionTitle = BuildInfo.appVersion == "dev"
      ? "개발 빌드 · 새 버전 확인 ↗"
      : "v\(BuildInfo.appVersion) · 새 버전 확인 ↗"
    let releasesButton = NSButton(
      title: versionTitle,
      target: self,
      action: #selector(openReleases)
    )
    releasesButton.bezelStyle = .inline
    releasesButton.controlSize = .small
    releasesButton.contentTintColor = Brand.statusBlue
    releasesButton.attributedTitle = NSAttributedString(
      string: releasesButton.title,
      attributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
        .foregroundColor: Brand.statusBlue,
      ]
    )
    releasesButton.toolTip = releasesURL
    let statusStrip = NSStackView(
      views: [statusIcon, status, statusSpacer, trustIcon, trustLabel, releasesButton]
    )
    statusStrip.orientation = .horizontal
    statusStrip.alignment = .centerY
    statusStrip.spacing = 7
    statusSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    statusSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    statusStrip.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true

    // Long machine-readable probe output must wrap inside the viewport, not resize the window.
    log.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    log.isEditable = false
    log.isSelectable = true
    log.isBezeled = false
    log.drawsBackground = false
    log.usesSingleLineMode = false
    log.lineBreakMode = .byCharWrapping
    log.maximumNumberOfLines = 0
    log.cell?.wraps = true
    log.cell?.isScrollable = false
    log.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    log.textColor = .labelColor
    log.stringValue = ""
    log.translatesAutoresizingMaskIntoConstraints = false
    logEmptyState.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    logEmptyState.textColor = .labelColor
    logEmptyState.isHidden = false
    logEmptyState.translatesAutoresizingMaskIntoConstraints = false

    let logDocument = NSView()
    logDocument.translatesAutoresizingMaskIntoConstraints = false
    logDocument.addSubview(log)
    logScroll.documentView = logDocument
    logScroll.hasVerticalScroller = true
    logScroll.borderType = .noBorder
    logScroll.drawsBackground = true
    logScroll.backgroundColor = Brand.surfaceStrong
    logScroll.wantsLayer = true
    logScroll.layer?.cornerRadius = 10
    logScroll.layer?.masksToBounds = true
    logScroll.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      logDocument.widthAnchor.constraint(equalTo: logScroll.contentView.widthAnchor),
      logDocument.heightAnchor.constraint(
        greaterThanOrEqualTo: logScroll.contentView.heightAnchor
      ),
      log.leadingAnchor.constraint(equalTo: logDocument.leadingAnchor, constant: 14),
      log.trailingAnchor.constraint(equalTo: logDocument.trailingAnchor, constant: -14),
      log.topAnchor.constraint(equalTo: logDocument.topAnchor, constant: 13),
      log.bottomAnchor.constraint(equalTo: logDocument.bottomAnchor, constant: -13),
    ])
    let logViewport = NSView()
    logViewportView = logViewport
    logViewport.isHidden = true
    logViewport.addSubview(logScroll)
    logViewport.addSubview(logEmptyState)
    NSLayoutConstraint.activate([
      logScroll.leadingAnchor.constraint(equalTo: logViewport.leadingAnchor),
      logScroll.trailingAnchor.constraint(equalTo: logViewport.trailingAnchor),
      logScroll.topAnchor.constraint(equalTo: logViewport.topAnchor),
      logScroll.bottomAnchor.constraint(equalTo: logViewport.bottomAnchor),
      logEmptyState.leadingAnchor.constraint(equalTo: logViewport.leadingAnchor, constant: 18),
      logEmptyState.trailingAnchor.constraint(
        lessThanOrEqualTo: logViewport.trailingAnchor,
        constant: -18
      ),
      logEmptyState.topAnchor.constraint(equalTo: logViewport.topAnchor, constant: 16),
      logViewport.heightAnchor.constraint(greaterThanOrEqualToConstant: 170),
    ])

    let logIcon = NSImageView(
      image: NSImage(
        systemSymbolName: "terminal.fill",
        accessibilityDescription: "실행 로그"
      ) ?? NSImage()
    )
    logIcon.contentTintColor = Brand.mint
    let logTitle = NSTextField(labelWithString: "실행 로그")
    logTitle.font = .systemFont(ofSize: 13, weight: .semibold)
    let logSpacer = NSView()
    logsToggle.bezelStyle = .inline
    logsToggle.target = self
    logsToggle.action = #selector(toggleLogs)
    let logHeader = NSStackView(views: [logIcon, logTitle, logSpacer, logsToggle])
    logHeader.orientation = .horizontal
    logHeader.alignment = .centerY
    logHeader.spacing = 7
    logSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    logSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    let logContent = NSStackView(views: [logHeader, logViewport])
    logContent.orientation = .vertical
    logContent.alignment = .leading
    logContent.distribution = .fill
    logContent.spacing = 10
    NSLayoutConstraint.activate([
      logHeader.widthAnchor.constraint(equalTo: logContent.widthAnchor),
      logViewport.widthAnchor.constraint(equalTo: logContent.widthAnchor),
    ])
    let logBox = makeCard(containing: logContent, inset: 14)
    logBox.setContentHuggingPriority(.defaultLow, for: .vertical)

    agentChoice.addItems(withTitles: ["Claude Code", "Codex"])
    for button in [launchButton, copyButton] {
      button.bezelStyle = .rounded
      button.target = self
      button.isEnabled = false
    }
    agentChoice.isEnabled = false
    launchButton.action = #selector(launchPractice)
    copyButton.action = #selector(copyStarterPrompt)
    let firstRunTitle = NSTextField(labelWithString: "설치 후 첫 코딩")
    firstRunTitle.font = .systemFont(ofSize: 13, weight: .semibold)
    checkButton.bezelStyle = .rounded
    checkButton.target = self
    checkButton.action = #selector(checkInstallation)
    checkButton.toolTip = "Terminal 설치가 끝나면 누르세요. 재설치 없이 실행 가능 여부만 확인합니다."
    let firstRunHeader = NSStackView(views: [firstRunTitle, NSView(), checkButton])
    let firstRunHint = NSTextField(wrappingLabelWithString:
      "도구 실행 확인 후 활성화됩니다. 새 연습 폴더에서 시작하고, 로그인·폴더 신뢰·프롬프트 붙여넣기는 직접 진행하세요.")
    firstRunHint.font = .systemFont(ofSize: 12)
    firstRunHint.textColor = .secondaryLabelColor
    let firstRunControls = NSStackView(views: [agentChoice, launchButton, copyButton])
    firstRunControls.spacing = 10
    let firstRun = NSStackView(views: [firstRunHeader, firstRunHint, firstRunControls])
    firstRunView = firstRun
    firstRun.orientation = .vertical
    firstRun.alignment = .leading
    firstRun.spacing = 8
    let content = NSStackView(views: [header, setupBox, statusStrip, firstRun, logBox])
    content.orientation = .vertical
    content.alignment = .leading
    content.spacing = 18
    content.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
    content.translatesAutoresizingMaskIntoConstraints = false
    let root = window.contentView!

    let material = NSVisualEffectView()
    material.material = .underWindowBackground
    material.blendingMode = .behindWindow
    material.state = .active
    material.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(material)
    root.addSubview(content)
    NSLayoutConstraint.activate([
      material.leadingAnchor.constraint(equalTo: root.leadingAnchor),
      material.trailingAnchor.constraint(equalTo: root.trailingAnchor),
      material.topAnchor.constraint(equalTo: root.topAnchor),
      material.bottomAnchor.constraint(equalTo: root.bottomAnchor),
      content.leadingAnchor.constraint(equalTo: root.leadingAnchor),
      content.trailingAnchor.constraint(equalTo: root.trailingAnchor),
      content.topAnchor.constraint(equalTo: root.topAnchor),
      content.bottomAnchor.constraint(equalTo: root.bottomAnchor),
      header.widthAnchor.constraint(equalTo: content.widthAnchor, constant: -56),
      setupBox.widthAnchor.constraint(equalTo: content.widthAnchor, constant: -56),
      statusStrip.widthAnchor.constraint(equalTo: content.widthAnchor, constant: -56),
      firstRun.widthAnchor.constraint(equalTo: content.widthAnchor, constant: -56),
      firstRunHint.widthAnchor.constraint(equalTo: firstRun.widthAnchor),
      firstRunHeader.widthAnchor.constraint(equalTo: firstRun.widthAnchor),
      logBox.widthAnchor.constraint(equalTo: content.widthAnchor, constant: -56),
    ])
    logBox.setContentHuggingPriority(.defaultLow, for: .vertical)
    setStatus("설치할 준비가 되었습니다.", style: .ready)
  }

  private func makeCard(containing view: NSView, inset: CGFloat) -> NSBox {
    let box = NSBox()
    box.boxType = .custom
    box.titlePosition = .noTitle
    box.fillColor = NSColor.controlBackgroundColor
    box.borderColor = NSColor.separatorColor
    box.borderWidth = 1
    box.cornerRadius = 14
    view.translatesAutoresizingMaskIntoConstraints = false
    box.contentView?.addSubview(view)
    guard let container = box.contentView else { return box }
    NSLayoutConstraint.activate([
      view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
      view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset),
      view.topAnchor.constraint(equalTo: container.topAnchor, constant: inset),
      view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -inset),
    ])
    return box
  }

  private enum StatusStyle {
    case ready
    case running
    case success
    case attention
    case failure
  }

  @objc private func profileDidChange() {
    setFirstRunEnabled(false)
    let index = profile.indexOfSelectedItem
    completedActionTitle = nil
    if profilePlans.indices.contains(index) {
      applyProfilePlan(profilePlans[index])
    } else {
      for choice in [coreChoice, runtimesChoice, dockerChoice, agentsChoice] { choice.isHidden = false }
      firstRunView?.isHidden = true
      updateProfileDetails()
    }
    updatePrimaryActionTitle()
  }

  @objc private func componentDidChange(_ sender: NSButton) {
    setFirstRunEnabled(false)
    if sender === agentsChoice && agentsChoice.state == .on {
      runtimesChoice.state = .on
    } else if sender === runtimesChoice && runtimesChoice.state == .off {
      agentsChoice.state = .off
    }
    completedActionTitle = nil
    profile.selectItem(at: profilePlans.count)
    updateProfileDetails()
    updatePrimaryActionTitle()
  }

  @objc private func toggleLogs() {
    let hidden = !(logViewportView?.isHidden ?? true)
    logViewportView?.isHidden = hidden
    logsToggle.title = hidden ? "상세 로그 보기" : "상세 로그 접기"
  }

  private func updatePrimaryActionTitle() {
    installButton.title = completedActionTitle ?? installActionTitle
  }

  @objc private func openToolsGuide() {
    guard let url = URL(string: toolsURL) else { return }
    NSWorkspace.shared.open(url)
  }

  @objc private func openReleases() {
    guard let url = URL(string: releasesURL) else { return }
    NSWorkspace.shared.open(url)
  }

  @objc private func openPermissionHelp() {
    let alert = NSAlert()
    alert.messageText = "관리자 권한이란?"
    alert.informativeText = """
      macOS에서 앱과 개발 도구 설치를 승인할 수 있는 ‘관리자’ 계정을 뜻합니다.

      이 앱에는 sudo 명령이나 비밀번호를 입력하지 않습니다. 처음 Xcode 또는 Homebrew를 준비할 때만 Terminal이나 macOS 시스템 창에서 직접 승인합니다.

      현재 계정이 관리자가 아니라면 이 Mac의 관리자에게 설치를 요청하세요.
      """
    alert.alertStyle = .informational
    alert.addButton(withTitle: "확인")
    alert.beginSheetModal(for: window)
  }

  private func applyProfilePlan(_ plan: InstallerProfile) {
    firstRunView?.isHidden = plan.id != "ai"
    for choice in [coreChoice, runtimesChoice, dockerChoice, agentsChoice] {
      choice.isHidden = plan.id == "ai"
    }
    runtimesChoice.state = plan.steps.contains("runtimes") ? .on : .off
    dockerChoice.state = plan.steps.contains("docker") ? .on : .off
    agentsChoice.state = plan.steps.contains("agents") ? .on : .off
    updateProfileDetails()
  }

  private func selectedStepIDs() -> [String] {
    var steps = ["prereqs", "brew"]
    if runtimesChoice.state == .on { steps.append("runtimes") }
    steps.append("shell")
    if dockerChoice.state == .on { steps.append("docker") }
    steps.append("git")
    if agentsChoice.state == .on { steps.append("agents") }
    return steps
  }

  private func updateProfileDetails() {
    setupHeight?.constant = profile.indexOfSelectedItem == 0 ? 250 : 300
    if profile.indexOfSelectedItem == 0 {
      profileDetails.stringValue = "Git · Node.js LTS/npm · Claude Code · Codex\n안전 훅과 새 터미널 PATH만 설정합니다. 다른 언어·Docker·셸 꾸미기는 설치하지 않습니다."
      profileDetails.toolTip = profileDetails.stringValue
      return
    }
    var lines = [
      "기본 도구: Xcode CLT · Homebrew · Git/gh · jq · ripgrep · fd · fzf · bat · tree · ast-grep · zoxide · starship · JetBrains Mono · Orca"
    ]
    if runtimesChoice.state == .on {
      lines.append("언어 런타임: mise · uv · bun · Node.js · Python · Go · Rust")
    }
    if dockerChoice.state == .on {
      lines.append("Docker: Colima · Docker CLI · Compose · Buildx")
    }
    if agentsChoice.state == .on {
      lines.append("AI 에이전트: Claude Code · Codex")
    }
    let details = lines.joined(separator: "\n")
    profileDetails.stringValue = details
    profileDetails.toolTip = details
  }

  private func setStatus(_ message: String, style: StatusStyle) {
    let presentation: (symbol: String, color: NSColor) = switch style {
    case .ready:
      ("circle.fill", .secondaryLabelColor)
    case .running:
      ("arrow.down.circle", Brand.statusBlue)
    case .success:
      ("checkmark.circle.fill", Brand.statusGreen)
    case .attention:
      ("exclamationmark.triangle.fill", .systemOrange)
    case .failure:
      ("xmark.circle.fill", Brand.statusRed)
    }
    status.stringValue = message
    status.textColor = presentation.color
    statusIcon.image = Brand.symbol(presentation.symbol)
    statusIcon.contentTintColor = presentation.color
    statusIcon.setAccessibilityLabel(message)
  }

  @objc private func startInstall() {
    dryRun.state = .off
    performInstall()
  }

  @objc private func startPreview() {
    dryRun.state = .on
    performInstall()
  }

  private func performInstall() {
    guard session == nil, !isPreparing else { return }
    setFirstRunEnabled(false)
    checkButton.isEnabled = false
    runWasAI = profile.indexOfSelectedItem == 0
    let preview = dryRun.state == .on
    let selectedSteps = selectedStepIDs()
    if !preview {
      switch administratorStatus() {
      case .administrator:
        let prerequisites = prerequisiteStatus()
        if prerequisites != .ready {
          do {
            let handoff = try createTerminalHandoff(steps: selectedSteps)
            logEmptyState.isHidden = true
            log.stringValue =
              """
              \(prerequisites.description) 첫 설치는 Terminal에서 계속합니다.
              macOS가 요청할 때 관리자 승인은 Terminal 또는 시스템 창에서 직접 진행합니다.
              이 앱은 sudo 명령이나 비밀번호를 받거나 저장하지 않습니다.

              """
            if
              (!BuildInfo.developerMode
                || ProcessInfo.processInfo.environment[
                  "STARTER_KIT_GUI_DISABLE_TERMINAL_OPEN"
                ] != "1")
              && !NSWorkspace.shared.open(handoff)
            {
              try? FileManager.default.removeItem(at: handoff)
              try? FileManager.default.removeItem(at: handoff.appendingPathExtension("payload.sh"))
              throw InstallerError.terminalOpenFailed
            }
            finish(
              code: 79,
              message: "처음 준비는 Terminal에서 계속합니다.",
              action: .terminalRequired,
              guidance: .terminalApprovalRequiredNoPassword
            )
          } catch {
            finish(
              code: 78,
              message: "Terminal 설치 준비 실패: \(error.localizedDescription)",
              action: .retry
            )
          }
          return
        }
      case .standardUser:
        logEmptyState.isHidden = true
        log.stringValue =
          """
          관리자 계정은 macOS에서 앱과 개발 도구 설치를 승인할 수 있는 계정입니다.
          이 앱에 sudo 명령이나 비밀번호를 입력하지 않습니다.
          이 Mac의 관리자에게 설치를 요청한 뒤 다시 실행하세요.

          """
        if
          !BuildInfo.developerMode
            || ProcessInfo.processInfo.environment["STARTER_KIT_GUI_EXIT_ON_FINISH"] != "1"
        {
          openPermissionHelp()
        }
        finish(
          code: 77,
          message: "실제 설치를 시작하려면 관리자 계정이 필요합니다.",
          action: .administratorRequired,
          guidance: .adminAccountRequiredNoPassword
        )
        return
      case .unavailable(let reason):
        finish(
          code: 78,
          message: "관리자 권한을 확인하지 못했습니다: \(reason)",
          action: .retry
        )
        return
      }
    }

    installButton.isEnabled = false
    previewButton.isEnabled = false
    profile.isEnabled = false
    runtimesChoice.isEnabled = false
    dockerChoice.isEnabled = false
    agentsChoice.isEnabled = false
    dryRun.isEnabled = false
    isPreparing = true
    preparationCancelled = false
    cancelButton.title = preview ? "미리보기 취소" : "설치 취소"
    cancelButton.isHidden = false
    cancelButton.isEnabled = true
    window.standardWindowButton(.closeButton)?.isEnabled = false
    setStatus("포함된 설치 파일을 확인하는 중…", style: .running)
    logEmptyState.isHidden = true
    log.stringValue = ""

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      self?.prepareAndRun(steps: selectedSteps, dryRun: preview)
    }
    if
      BuildInfo.developerMode,
      ProcessInfo.processInfo.environment["STARTER_KIT_GUI_QUIT_BEFORE_START"] == "1"
    {
      DispatchQueue.main.async {
        NSApplication.shared.terminate(nil)
      }
    }
  }

  @objc private func cancelInstall() {
    cancelButton.isEnabled = false
    setStatus("설치를 안전하게 취소하는 중…", style: .running)
    if let session {
      session.cancel()
    } else if isPreparing {
      preparationCancelled = true
    }
  }

  private func createTerminalHandoff(steps: [String]) throws -> URL {
    let environment = ProcessInfo.processInfo.environment
    let handoff: URL
    if BuildInfo.developerMode, let path = environment["STARTER_KIT_GUI_HANDOFF_PATH"] {
      handoff = URL(fileURLWithPath: path)
    } else {
      handoff = FileManager.default.temporaryDirectory
        .appendingPathComponent("lazy-starter-kit-\(UUID().uuidString).command")
    }
    let resolved = try resolveInstallerPayload()
    defer {
      if resolved.removeAfterRun {
        try? FileManager.default.removeItem(at: resolved.url)
      }
    }
    let payload = handoff.appendingPathExtension("payload.sh")
    let expectedSHA256 = resolved.removeAfterRun
      ? (environment["STARTER_KIT_INSTALL_SHA256"] ?? "")
      : BuildInfo.installerSHA256
    let data = try validatedInstallerData(
      from: resolved.url,
      expectedSHA256: expectedSHA256
    )
    try data.write(to: payload, options: .atomic)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o600],
      ofItemAtPath: payload.path
    )
    let quotedPayload = "'" + payload.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    let quotedRef = "'" + BuildInfo.releaseRef.replacingOccurrences(of: "'", with: "'\\''") + "'"
    let quotedCommit =
      "'" + BuildInfo.releaseCommit.replacingOccurrences(of: "'", with: "'\\''") + "'"
    let quotedRepository =
      "'" + canonicalRepositoryURL.replacingOccurrences(of: "'", with: "'\\''") + "'"
    let cloneDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("lazy-starter-kit-\(UUID().uuidString)")
      .path
    let quotedCloneDirectory =
      "'" + cloneDirectory.replacingOccurrences(of: "'", with: "'\\''") + "'"
    let selected = runWasAI ? "--profile ai" : "--only " + steps.joined(separator: ",")
    let script =
      """
      #!/bin/bash
      set -u
      SELF="$0"
      PAYLOAD=\(quotedPayload)
      cleanup() {
        /bin/rm -f "$PAYLOAD" "$SELF"
      }
      trap cleanup EXIT

      printf '\\nLazy Starter Kit first-time setup\\n'
      printf 'macOS가 요청할 때 관리자 승인은 이 Terminal 창에서 직접 진행하세요.\\n\\n'
      STARTER_KIT_REPO=\(quotedRepository) \\
      STARTER_KIT_DIR=\(quotedCloneDirectory) \\
      STARTER_KIT_EPHEMERAL_ROOT=\(quotedCloneDirectory) \\
      STARTER_KIT_BRANCH=\(quotedRef) \\
      STARTER_KIT_COMMIT=\(quotedCommit) \\
      /bin/bash "$PAYLOAD" --yes \(selected)
      status=$?
      printf '\\n설치기가 종료되었습니다 (status: %s).\\n' "$status"
      exit "$status"

      """
    do {
      try script.write(to: handoff, atomically: true, encoding: .utf8)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o700],
        ofItemAtPath: handoff.path
      )
    } catch {
      try? FileManager.default.removeItem(at: payload)
      try? FileManager.default.removeItem(at: handoff)
      throw error
    }
    return handoff
  }

  nonisolated private func prepareAndRun(steps: [String], dryRun: Bool) {
    do {
      let payload = try resolveInstallerPayload()
      Task { @MainActor [weak self] in
        guard let self else { return }
        if self.preparationCancelled {
          if payload.removeAfterRun {
            try? FileManager.default.removeItem(at: payload.url)
          }
          self.finish(
            code: 130,
            message: dryRun ? "미리보기가 취소되었습니다." : "설치가 취소되었습니다.",
            action: .cancelled
          )
        } else {
          self.beginSession(payload: payload, steps: steps, dryRun: dryRun)
        }
      }
    } catch {
      Task { @MainActor [weak self] in
        guard let self else { return }
        if self.preparationCancelled {
          self.finish(
            code: 130,
            message: dryRun ? "미리보기가 취소되었습니다." : "설치가 취소되었습니다.",
            action: .cancelled
          )
        } else {
          self.finish(
            code: 1,
            message: "설치 파일 확인 실패: \(error.localizedDescription)",
            action: .retry
          )
        }
      }
    }
  }

  private func beginSession(
    payload: InstallerPayload,
    steps: [String],
    dryRun: Bool
  ) {
    isPreparing = false
    let environment = installerEnvironment()
    let processSession = InstallerProcessSession(
      payload: payload.url,
      arguments:
        ["--yes"] + (runWasAI ? ["--profile", "ai"] : ["--only", steps.joined(separator: ",")])
        + (dryRun ? ["--dry-run"] : []),
      environment: environment,
      removePayloadAfterRun: payload.removeAfterRun,
      onOutput: { [weak self] text in
        DispatchQueue.main.async {
          guard let self else { return }
          self.appendLog(text)
          if
            BuildInfo.developerMode,
            let sentinel = ProcessInfo.processInfo.environment[
              "STARTER_KIT_GUI_CANCEL_ON_OUTPUT"
            ],
            text.contains(sentinel)
          {
            self.cancelInstall()
          }
        }
      },
      onFinish: { [weak self] result in
        DispatchQueue.main.async {
          self?.handleSessionResult(result, dryRun: dryRun)
        }
      }
    )
    session = processSession
    cancelButton.isHidden = false
    cancelButton.title = dryRun ? "미리보기 취소" : "설치 취소"
    cancelButton.isEnabled = true
    window.standardWindowButton(.closeButton)?.isEnabled = false
    setStatus(
      dryRun ? "변경 내용을 미리 보는 중…" : "구성을 적용하는 중…",
      style: .running
    )
    if
      BuildInfo.developerMode,
      ProcessInfo.processInfo.environment["STARTER_KIT_GUI_CANCEL_BEFORE_START"] == "1"
    {
      cancelInstall()
    }
    DispatchQueue.global(qos: .userInitiated).async { [weak self, weak processSession] in
      guard let self, let processSession else { return }
      do {
        try processSession.start()
      } catch {
        DispatchQueue.main.async {
          guard self.session === processSession else { return }
          self.finish(
            code: 1,
            message: "설치기를 시작하지 못했습니다: \(error.localizedDescription)",
            action: .retry
          )
        }
      }
    }
  }

  private func firstUseGuidance() -> String {
    let steps = selectedStepIDs()
    var checks = ["brew --version; git --version; gh --version"]
    if steps.contains("runtimes") {
      checks.append("node --version; python3 --version; go version; rustc --version")
    }
    if steps.contains("docker") {
      checks.append("docker --version; colima --version")
    }
    if steps.contains("agents") {
      checks.append("claude --version; codex --version")
    }
    var lines = [
      "",
      "설치기 종료는 도구 검증이 아닙니다. 오류나 건너뛴 항목은 위 로그를 확인하세요.",
      "새 터미널을 열고 선택한 도구의 버전을 직접 확인하세요:",
    ] + checks + [
      "",
      "첫 프로젝트: 작업 폴더에서 git init을 실행하세요.",
    ]
    if steps.contains("agents") {
      lines.append("그 폴더에서 claude 또는 codex를 실행하고 도구 자체 로그인 안내를 따르세요.")
    }
    return lines.joined(separator: "\n") + "\n"
  }

  private func handleSessionResult(_ result: InstallerProcessResult, dryRun: Bool) {
    if result.cancelled {
      finish(
        code: 130,
        message: dryRun ? "미리보기가 취소되었습니다." : "설치가 취소되었습니다.",
        action: .cancelled,
        capturedLog: result.output
      )
      return
    }
    let action: CompletionAction =
      if result.status != 0 {
        .retry
      } else if dryRun {
        .startInstall
      } else if runWasAI {
        result.output.split(separator: "\n").contains("LSK_AI_READINESS=ready") ? .firstRun : .actionNeeded
      } else {
        .openNewTerminal
      }
    finish(
      code: action == .actionNeeded ? 1 : result.status,
      message: result.status == 0
        ? (
          dryRun
            ? "미리보기 완료 · 구성 적용 가능"
            : (action == .firstRun
              ? "도구 실행 확인 완료 · 계정 로그인 후 시작하세요."
              : (action == .actionNeeded
                ? "실행 확인이 필요합니다. 설치 결과 확인 또는 상세 로그를 확인하세요."
                : "설치기 완료 · 도구 확인 필요"))
        )
        : (dryRun
          ? "미리보기가 완료되지 않았습니다. 아래 로그를 확인해 주세요."
          : "설치가 완료되지 않았습니다. 아래 로그를 확인해 주세요."),
      action: action,
      capturedLog: result.output + (action == .openNewTerminal ? firstUseGuidance() : "")
    )
  }

  @MainActor private func appendLog(_ text: String) {
    log.stringValue.append(text)
    if session != nil {
      let stages: [(String, String)] = [
        ("Prerequisites:", "설치에 필요한 macOS 도구를 준비하는 중…"),
        ("Homebrew packages", "Git과 설치 도구를 준비하는 중…"),
        ("Node.js LTS", "AI 도구 실행에 필요한 Node.js를 준비하는 중…"),
        ("Make AI commands", "새 터미널에서 명령을 찾도록 설정하는 중…"),
        ("AI agents:", "Claude Code와 Codex를 준비하는 중…"),
        ("Checking required", "설치된 도구가 실제로 실행되는지 확인하는 중…"),
      ]
      for (marker, message) in stages where text.contains(marker) {
        setStatus(message, style: .running)
      }
    }
    log.invalidateIntrinsicContentSize()
    DispatchQueue.main.async { [weak self] in
      self?.scrollLogToBottom()
    }
  }

  private func scrollLogToBottom() {
    log.superview?.layoutSubtreeIfNeeded()
    logScroll.layoutSubtreeIfNeeded()
    logScroll.contentView.scroll(to: .zero)
    logScroll.reflectScrolledClipView(logScroll.contentView)
  }

  private func finish(
    code: Int32,
    message: String,
    action: CompletionAction,
    guidance: PermissionGuidance? = nil,
    capturedLog: String? = nil
  ) {
    session = nil
    isPreparing = false
    preparationCancelled = false
      if let capturedLog {
        log.stringValue = capturedLog
        log.invalidateIntrinsicContentSize()
        log.superview?.layoutSubtreeIfNeeded()
        scrollLogToBottom()
      }
      let style: StatusStyle = switch action {
      case .startInstall, .openNewTerminal, .firstRun:
        .success
      case .actionNeeded:
        .attention
      case .cancelled, .terminalRequired:
        .ready
      case .administratorRequired, .retry:
        .failure
      }
      setStatus(message, style: style)
      switch action {
      case .startInstall:
        completedActionTitle = "이 구성 적용"
        dryRun.state = .off
      case .openNewTerminal, .firstRun:
        completedActionTitle = "구성 다시 적용"
      case .terminalRequired:
        completedActionTitle = "Terminal 다시 열기"
        if runWasAI { setStatus("Terminal 설치 후 ‘설치 결과 확인’을 누르세요.", style: .attention) }
      case .administratorRequired, .retry:
        completedActionTitle = "다시 확인"
      case .cancelled, .actionNeeded:
        completedActionTitle = nil
      }
      updatePrimaryActionTitle()
      setFirstRunEnabled(action == .firstRun && code == 0)
      if code != 0 && action != .cancelled && action != .terminalRequired {
        logViewportView?.isHidden = false
        logsToggle.title = "상세 로그 접기"
      }
      previewButton.isEnabled = true
      checkButton.isEnabled = true
      installButton.isEnabled = true
      cancelButton.isHidden = true
      cancelButton.isEnabled = true
      profile.isEnabled = true
      runtimesChoice.isEnabled = true
      dockerChoice.isEnabled = true
      agentsChoice.isEnabled = true
      dryRun.isEnabled = true
      window.standardWindowButton(.closeButton)?.isEnabled = true
      let environment = BuildInfo.developerMode
        ? ProcessInfo.processInfo.environment
        : [:]
      if let snapshotPath = environment["STARTER_KIT_GUI_SNAPSHOT"] {
        do {
          try renderSnapshot(to: snapshotPath)
        } catch {
          appendLog("\nQA snapshot failed: \(error.localizedDescription)\n")
        }
      }
      if let resultPath = environment["STARTER_KIT_GUI_RESULT"] {
        do {
          try "\(code)\n\(message)\n\(action.rawValue)\n\(guidance?.rawValue ?? "")\n".write(
            toFile: resultPath,
            atomically: true,
            encoding: .utf8
          )
        } catch {
          appendLog("\nQA completion signal failed: \(error.localizedDescription)\n")
        }
      }
      if let logResultPath = environment["STARTER_KIT_GUI_LOG_RESULT"] {
        do {
          try log.stringValue.write(
            toFile: logResultPath,
            atomically: true,
            encoding: .utf8
          )
        } catch {
          appendLog("\nQA log signal failed: \(error.localizedDescription)\n")
        }
      }
      if terminateAfterCancellation {
        terminateAfterCancellation = false
        NSApplication.shared.terminate(nil)
        return
      }
      if environment["STARTER_KIT_GUI_EXIT_ON_FINISH"] == "1" {
        if environment["STARTER_KIT_GUI_COPY_PROMPT"] == "1" {
          copyStarterPrompt()
        }
        if let agent = environment["STARTER_KIT_GUI_FIRST_RUN"], launchButton.isEnabled {
          agentChoice.selectItem(at: agent == "codex" ? 1 : 0)
          launchPractice()
        }
        if let path = environment["STARTER_KIT_GUI_ONBOARDING_RESULT"] {
          do {
            let state: [String: Any] = [
              "profile": profilePlans.indices.contains(profile.indexOfSelectedItem)
                ? profilePlans[profile.indexOfSelectedItem].id : "custom",
              "launchEnabled": launchButton.isEnabled,
              "copyEnabled": copyButton.isEnabled,
              "practiceFolder": practiceFolder?.path ?? "",
              "practiceCommand": practiceCommand?.path ?? "",
              "clipboardMatchesPrompt": environment["STARTER_KIT_GUI_COPY_PROMPT"] == "1"
                && promptPasteboard.string(forType: .string) == starterPrompt,
              "clipboardLength": environment["STARTER_KIT_GUI_COPY_PROMPT"] == "1"
                ? (promptPasteboard.string(forType: .string)?.count ?? 0) : 0,
            ]
            try JSONSerialization.data(withJSONObject: state, options: [.sortedKeys])
              .write(to: URL(fileURLWithPath: path))
          } catch {
            fputs("onboarding QA signal failed: \(error)\n", stderr)
            exit(1)
          }
        }
        NSApplication.shared.terminate(nil)
      }
  }

  private func setFirstRunEnabled(_ enabled: Bool) {
    launchButton.isEnabled = enabled
    copyButton.isEnabled = enabled
    agentChoice.isEnabled = enabled
  }

  @objc private func copyStarterPrompt() {
    guard copyButton.isEnabled else { return }
    promptPasteboard.clearContents()
    if !promptPasteboard.setString(starterPrompt, forType: .string) {
      setStatus("프롬프트를 복사하지 못했습니다. 다시 시도하세요.", style: .attention)
      return
    }
    setStatus("프롬프트를 복사했습니다. 로그인 후 직접 붙여넣고 전송하세요.", style: .ready)
  }

  @objc private func checkInstallation() {
    guard session == nil, !isPreparing else { return }
    setFirstRunEnabled(false)
    guard let checkout = readinessInstaller() else {
      finish(code: 1, message: "설치 파일이 없습니다. Terminal 설치를 끝낸 뒤 다시 확인하세요.", action: .actionNeeded)
      return
    }
    checkButton.isEnabled = false
    installButton.isEnabled = false
    previewButton.isEnabled = false
    profile.isEnabled = false
    runtimesChoice.isEnabled = false
    dockerChoice.isEnabled = false
    agentsChoice.isEnabled = false
    cancelButton.isHidden = false
    cancelButton.isEnabled = true
    cancelButton.title = "점검 취소"
    window.standardWindowButton(.closeButton)?.isEnabled = false
    logEmptyState.isHidden = true
    log.stringValue = ""
    setStatus("새 터미널에서 AI 도구 실행을 확인하는 중…", style: .running)
    var environment = installerEnvironment()
    environment.removeValue(forKey: "STARTER_KIT_EPHEMERAL_ROOT")
    let check = InstallerProcessSession(
      payload: checkout,
      arguments: ["--profile", "ai", "--doctor-json"],
      environment: environment,
      removePayloadAfterRun: false,
      onOutput: { [weak self] text in
        DispatchQueue.main.async { self?.appendLog(text) }
      },
      onFinish: { [weak self] result in
        DispatchQueue.main.async {
          guard let self else { return }
          if result.cancelled {
            self.finish(code: 130, message: "점검이 취소되었습니다.", action: .cancelled, capturedLog: result.output)
            return
          }
          do {
            let report = try JSONDecoder().decode(AIReadinessReport.self, from: Data(result.output.utf8))
            let tools = Set(report.items.filter { $0.state == "ok" }.map(\.id))
            let ready = result.status == 0 && report.summary.missing == 0 && report.summary.pathOnly == 0
              && Set(["git", "node", "npm", "claude", "codex", "ai-safety"]).isSubset(of: tools)
            self.finish(code: ready ? 0 : 1,
              message: ready ? "도구 실행 확인 완료 · 계정 로그인 후 시작하세요." : "설치가 끝나지 않았거나 실행할 수 없는 도구가 있습니다. 상세 로그를 확인하세요.",
              action: ready ? .firstRun : .actionNeeded, capturedLog: result.output)
          } catch {
            self.finish(code: 1, message: "설치 결과를 확인하지 못했습니다: \(error.localizedDescription)",
              action: .actionNeeded, capturedLog: result.output)
          }
        }
      }
    )
    session = check
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      do { try check.start() }
      catch {
        DispatchQueue.main.async {
          self?.finish(code: 1, message: "점검을 시작하지 못했습니다: \(error.localizedDescription)", action: .actionNeeded)
        }
      }
    }
  }

  @objc private func launchPractice() {
    guard launchButton.isEnabled, session == nil, !isPreparing else { return }
    let agent = agentChoice.indexOfSelectedItem == 1 ? "codex" : "claude"
    let environment = ProcessInfo.processInfo.environment
    let home = URL(fileURLWithPath: environment["HOME"] ?? NSHomeDirectory())
    do {
      // mkdtemp creates a new directory atomically; existing projects are never reused.
      var template = Array(home.appendingPathComponent("AI Practice 연습-XXXXXX").path.utf8CString)
      guard let created = mkdtemp(&template) else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
      }
      let folder = URL(fileURLWithPath: String(cString: created))
      practiceFolder = folder
      let command = FileManager.default.temporaryDirectory
        .appendingPathComponent("lazy-starter-kit-practice-\(UUID().uuidString).command")
      func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
      }
      let shellCommand = "cd -- \(quote(folder.path)) && exec \(agent)"
      let script = "#!/bin/bash\n/bin/rm -f -- \"$0\"\nexec /bin/zsh -lic \(quote(shellCommand))\n"
      try script.write(to: command, atomically: true, encoding: .utf8)
      try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: command.path)
      practiceCommand = command
      if !(BuildInfo.developerMode && environment["STARTER_KIT_GUI_DISABLE_TERMINAL_OPEN"] == "1") {
        guard NSWorkspace.shared.open(command) else { throw InstallerError.terminalOpenFailed }
      }
      setStatus("새 연습 폴더에서 시작합니다. 로그인과 폴더 신뢰는 직접 승인하세요.", style: .ready)
    } catch {
      setStatus("연습 터미널을 열지 못했습니다: \(error.localizedDescription)", style: .failure)
    }
  }

  private func readinessInstaller() -> URL? {
    if BuildInfo.developerMode,
      let root = ProcessInfo.processInfo.environment["STARTER_KIT_GUI_CHECK_ROOT"] {
      return URL(fileURLWithPath: root).appendingPathComponent("install.sh")
    }
    guard let installer = Bundle.main.resourceURL?
      .appendingPathComponent("readiness/install.sh") else { return nil }
    do {
      _ = try validatedInstallerData(from: installer, expectedSHA256: BuildInfo.installerSHA256)
      return installer
    } catch {
      appendLog("\n설치 결과 확인 파일 오류: \(error.localizedDescription)\n")
      return nil
    }
  }

  func saveSnapshot(to path: String, contentSize: NSSize? = nil) throws {
    buildUI()
    if let contentSize { window.setContentSize(contentSize) }
    try renderSnapshot(to: path)
  }

  func saveStateSnapshot(to path: String, state: String) throws {
    buildUI()
    switch state {
    case "standard-user":
      dryRun.state = .off
      logEmptyState.isHidden = true
      log.stringValue =
        """
        관리자 계정은 macOS에서 앱과 개발 도구 설치를 승인할 수 있는 계정입니다.
        이 앱에 sudo 명령이나 비밀번호를 입력하지 않습니다.
        이 Mac의 관리자에게 설치를 요청한 뒤 다시 실행하세요.
        """
      setStatus("실제 설치를 시작하려면 관리자 계정이 필요합니다.", style: .failure)
      installButton.title = "다시 확인"
    case "terminal-required":
      dryRun.state = .off
      logEmptyState.isHidden = true
      log.stringValue =
        """
        Homebrew 첫 설치는 Terminal에서 계속합니다.
        macOS가 요청할 때 관리자 승인은 Terminal 또는 시스템 창에서 직접 진행합니다.
        이 앱은 sudo 명령이나 비밀번호를 받거나 저장하지 않습니다.
        """
      setStatus("처음 준비는 Terminal에서 계속합니다.", style: .ready)
      installButton.title = "Terminal 다시 열기"
    case "ready-success":
      setFirstRunEnabled(true)
      dryRun.state = .off
      logEmptyState.isHidden = true
      log.stringValue = "qa-selected:--yes --only \(selectedStepIDs().joined(separator: ","))\nqa-final\n"
        + firstUseGuidance()
      setStatus(
        "설치기 완료 · 도구 확인 필요",
        style: .success
      )
      installButton.title = "구성 다시 적용"
    case "advanced-full":
      profile.selectItem(at: 2)
      applyProfilePlan(profilePlans[2])
    case "custom-core":
      applyProfilePlan(profilePlans[2])
      profile.selectItem(at: profilePlans.count)
      runtimesChoice.state = .off
      dockerChoice.state = .off
      agentsChoice.state = .off
      updateProfileDetails()
    case "running":
      profile.isEnabled = false
      runtimesChoice.isEnabled = false
      dockerChoice.isEnabled = false
      agentsChoice.isEnabled = false
      dryRun.isEnabled = false
      installButton.isEnabled = false
      cancelButton.isHidden = false
      cancelButton.title = "미리보기 취소"
      logEmptyState.isHidden = true
      log.stringValue = "설치 단계를 준비했습니다.\n패키지 구성을 적용하고 있습니다.\n"
      setStatus("구성을 적용하는 중…", style: .running)
    case "cancelled":
      logEmptyState.isHidden = true
      log.stringValue = "사용자 요청으로 설치 프로세스 트리를 종료했습니다.\n"
      setStatus("미리보기가 취소되었습니다.", style: .ready)
      completedActionTitle = nil
      updatePrimaryActionTitle()
    default:
      throw CocoaError(.fileReadCorruptFile)
    }
    try renderSnapshot(to: path)
  }

  private func renderSnapshot(to path: String) throws {
    window.center()
    window.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
    window.contentView?.layoutSubtreeIfNeeded()
    window.displayIfNeeded()
    guard let view = window.contentView else { throw CocoaError(.fileWriteUnknown) }
    let bounds = view.bounds
    guard
      let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(bounds.width),
        pixelsHigh: Int(bounds.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
      )
    else { throw CocoaError(.fileWriteUnknown) }
    bitmap.size = bounds.size
    view.cacheDisplay(in: view.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
      throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: URL(fileURLWithPath: path), options: .atomic)
  }
}

@MainActor private var applicationController: InstallerController?

let arguments = CommandLine.arguments
if arguments.contains("--self-test") {
  selfTest()
} else if let index = arguments.firstIndex(of: "--render-icon"), index + 1 < arguments.count {
  MainActor.assumeIsolated {
    do {
      let size = index + 2 < arguments.count
        ? CGFloat(Double(arguments[index + 2]) ?? 1024)
        : 1024
      try Brand.writeAppIconPNG(to: arguments[index + 1], size: size)
    } catch {
      fputs("icon rendering failed: \(error.localizedDescription)\n", stderr)
      exit(1)
    }
  }
} else {
  MainActor.assumeIsolated {
    let app = NSApplication.shared
    installMainMenu(for: app)
    if
      let appearanceIndex = arguments.firstIndex(of: "--appearance"),
      appearanceIndex + 1 < arguments.count
    {
      app.appearance = NSAppearance(
        named: arguments[appearanceIndex + 1] == "light" ? .aqua : .darkAqua
      )
    }
    let controller = InstallerController()
    if let index = arguments.firstIndex(of: "--snapshot"), index + 1 < arguments.count {
      do {
        try controller.saveSnapshot(to: arguments[index + 1])
      } catch {
        fputs("snapshot failed: \(error.localizedDescription)\n", stderr)
        exit(1)
      }
    } else if
      let index = arguments.firstIndex(of: "--snapshot-state"),
      index + 2 < arguments.count
    {
      do {
        try controller.saveStateSnapshot(
          to: arguments[index + 1],
          state: arguments[index + 2]
        )
      } catch {
        fputs("state snapshot failed: \(error.localizedDescription)\n", stderr)
        exit(1)
      }
    } else if
      let index = arguments.firstIndex(of: "--snapshot-size"),
      index + 3 < arguments.count,
      let width = Double(arguments[index + 2]),
      let height = Double(arguments[index + 3])
    {
      do {
        try controller.saveSnapshot(
          to: arguments[index + 1],
          contentSize: NSSize(width: width, height: height)
        )
      } catch {
        fputs("snapshot failed: \(error.localizedDescription)\n", stderr)
        exit(1)
      }
    } else {
      applicationController = controller
      app.delegate = controller
      app.run()
    }
  }
}
