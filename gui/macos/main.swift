import AppKit
import Foundation

private struct InstallerProfile {
  let id: String
  let title: String
  let steps: [String]
  let details: String
}

private let profilePlans = [
  InstallerProfile(
    id: "full",
    title: "전체 설치",
    steps: ["prereqs", "brew", "runtimes", "shell", "docker", "git", "agents"],
    details:
      "기본 도구: Xcode CLT · Homebrew · Git/gh · jq · ripgrep · fd · fzf · bat · tree · ast-grep · zoxide · starship\n"
      + "런타임/앱: mise · uv · bun · Node.js · Python · Go · Rust · JetBrains Mono · Orca\n"
      + "추가 구성: Colima · Docker CLI/Compose/Buildx · Claude Code · Codex · gajae-code · lazycodex"
  ),
  InstallerProfile(
    id: "minimal",
    title: "최소 설치",
    steps: ["prereqs", "brew", "runtimes", "shell", "git"],
    details:
      "기본 도구: Xcode CLT · Homebrew · Git/gh · jq · ripgrep · fd · fzf · bat · tree · ast-grep · zoxide · starship\n"
      + "런타임/앱: mise · uv · bun · Node.js · Python · Go · Rust · JetBrains Mono · Orca\n"
      + "제외 단계: Docker 환경 설정 · AI 에이전트 설정 (Docker/Colima 패키지는 Homebrew 구성에 포함)"
  ),
  InstallerProfile(
    id: "work",
    title: "회사 PC용",
    steps: ["prereqs", "brew", "runtimes", "shell", "git", "agents"],
    details:
      "기본 도구: Xcode CLT · Homebrew · Git/gh · jq · ripgrep · fd · fzf · bat · tree · ast-grep · zoxide · starship\n"
      + "런타임/앱: mise · uv · bun · Node.js · Python · Go · Rust · JetBrains Mono · Orca\n"
      + "추가 구성: Claude Code · Codex · gajae-code · lazycodex (Docker 환경 설정 단계 제외)"
  ),
]
private let profiles = profilePlans.map(\.id)
private let defaultInstallerURL =
  "https://raw.githubusercontent.com/Heoooooon/lazy-starter-kit/main/install.sh"
private let toolsURL = "https://cmore.dev/lazy-starter-kit/tools/"

private enum CompletionAction: String {
  case administratorRequired = "administrator-required"
  case openNewTerminal = "open-new-terminal"
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
  case terminalOpenFailed

  var errorDescription: String? {
    switch self {
    case .terminalOpenFailed:
      "Terminal을 열지 못했습니다."
    }
  }
}

private final class OutputCapture: @unchecked Sendable {
  private let lock = NSLock()
  private var value = ""

  func append(_ text: String) {
    lock.lock()
    value.append(text)
    lock.unlock()
  }

  func snapshot() -> String {
    lock.lock()
    defer { lock.unlock() }
    return value
  }
}

private func administratorStatus() -> AdministratorStatus {
  if let override = ProcessInfo.processInfo.environment["STARTER_KIT_GUI_ADMIN_STATUS"] {
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
  if let override = ProcessInfo.processInfo.environment["STARTER_KIT_GUI_PREREQUISITES"] {
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
    "interfaceVersion": 3,
    "profiles": profiles,
    "profileSteps": profileSteps,
    "supportsAppearanceSnapshots": true,
    "supportsCustomSelection": true,
    "supportsDryRun": true,
    "supportsRepeatApply": true,
    "toolsURL": toolsURL,
    "installerURL": defaultInstallerURL,
  ]
  let data = try! JSONSerialization.data(withJSONObject: contract, options: [.sortedKeys])
  print(String(decoding: data, as: UTF8.self))
}

@MainActor
private final class InstallerController: NSObject, NSApplicationDelegate {
  private let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 760, height: 720),
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
  private let installButton = NSButton(title: "미리보기 시작", target: nil, action: nil)
  private let statusIcon = NSImageView()
  private let status = NSTextField(labelWithString: "준비됨")
  private let log = NSTextField()
  private let logScroll = NSScrollView()
  private let logEmptyState = NSTextField(
    wrappingLabelWithString:
      "준비가 되었습니다.\n\n설치 구성을 확인한 뒤 미리보기를 시작하세요.\n실행되는 명령과 변경 예정 항목이 여기에 표시됩니다."
  )
  private var task: Process?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.applicationIconImage = Brand.appIcon(size: 512)
    buildUI()
    window.center()
    window.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
    let environment = ProcessInfo.processInfo.environment
    if
      let profileID = environment["STARTER_KIT_GUI_PROFILE"],
      let index = profilePlans.firstIndex(where: { $0.id == profileID })
    {
      profile.selectItem(at: index)
      applyProfilePlan(profilePlans[index])
    }
    if environment["STARTER_KIT_GUI_DRY_RUN"] == "0" {
      dryRun.state = .off
      installButton.title = "설치 시작"
    }
    if environment["STARTER_KIT_GUI_AUTOSTART"] == "1" {
      DispatchQueue.main.async { [weak self] in self?.startInstall() }
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

  private func buildUI() {
    window.title = "Lazy Starter Kit Installer"
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
        "필요할 때마다 개발 환경을 점검하고 다시 적용합니다. 먼저 변경 내용을 확인하세요."
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
    agentsChoice.toolTip = "Claude Code, Codex, gajae-code와 lazycodex"
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
    toolsButton.toolTip = toolsURL
    let permissionButton = NSButton(
      title: "관리자 권한이란?",
      target: self,
      action: #selector(openPermissionHelp)
    )
    permissionButton.bezelStyle = .inline
    permissionButton.controlSize = .small
    permissionButton.toolTip = "관리자 계정과 비밀번호 처리 방식을 설명합니다."
    let componentRow = NSStackView(
      views: [componentChoices, componentSpacer, permissionButton, toolsButton]
    )
    componentRow.orientation = .horizontal
    componentRow.alignment = .centerY
    componentRow.spacing = 10

    dryRun.state = .on
    dryRun.toolTip = "처음에는 컴퓨터를 바꾸지 않고 설치 계획만 보여줍니다."
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
    NSLayoutConstraint.activate([
      profile.widthAnchor.constraint(greaterThanOrEqualToConstant: 168),
      installButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
      installButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
    ])

    let controlsSpacer = NSView()
    controlsSpacer.setContentHuggingPriority(
      NSLayoutConstraint.Priority(249),
      for: .horizontal
    )
    controlsSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    let controls = NSStackView(views: [profile, dryRun, controlsSpacer, installButton])
    controls.orientation = .horizontal
    controls.alignment = .centerY
    controls.spacing = 14

    let setupHint = NSTextField(
      wrappingLabelWithString:
        "미리보기는 시스템을 변경하지 않습니다. 앱을 응용 프로그램 폴더에 보관하면 언제든 다시 점검하고 적용할 수 있습니다."
    )
    setupHint.font = .systemFont(ofSize: 12)
    setupHint.textColor = .tertiaryLabelColor
    let setupContent = NSStackView(
      views: [profileHeader, controls, componentRow, profileDetails, setupHint]
    )
    setupContent.orientation = .vertical
    setupContent.alignment = .leading
    setupContent.spacing = 11
    NSLayoutConstraint.activate([
      controls.widthAnchor.constraint(equalTo: setupContent.widthAnchor),
      componentRow.widthAnchor.constraint(equalTo: setupContent.widthAnchor),
      profileDetails.widthAnchor.constraint(equalTo: setupContent.widthAnchor),
      setupHint.widthAnchor.constraint(equalTo: setupContent.widthAnchor),
    ])
    let setupBox = makeCard(containing: setupContent, inset: 18)

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
    let trustLabel = NSTextField(labelWithString: "미리보기 기본 · 반복 실행 가능")
    trustLabel.font = .systemFont(ofSize: 11, weight: .medium)
    trustLabel.textColor = .secondaryLabelColor
    let statusStrip = NSStackView(views: [statusIcon, status, statusSpacer, trustIcon, trustLabel])
    statusStrip.orientation = .horizontal
    statusStrip.alignment = .centerY
    statusStrip.spacing = 7
    statusSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    statusSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    statusStrip.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true

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
    let logHint = NSTextField(labelWithString: "⌘A로 선택 · 복사 가능")
    logHint.font = .systemFont(ofSize: 11)
    logHint.textColor = .tertiaryLabelColor
    let logHeader = NSStackView(views: [logIcon, logTitle, logSpacer, logHint])
    logHeader.orientation = .horizontal
    logHeader.alignment = .centerY
    logHeader.spacing = 7
    logSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    logSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    let logContent = NSStackView(views: [logHeader, logViewport])
    logContent.orientation = .vertical
    logContent.alignment = .leading
    logContent.spacing = 10
    NSLayoutConstraint.activate([
      logHeader.widthAnchor.constraint(equalTo: logContent.widthAnchor),
      logViewport.widthAnchor.constraint(equalTo: logContent.widthAnchor),
    ])
    let logBox = makeCard(containing: logContent, inset: 14)

    let content = NSStackView(views: [header, setupBox, statusStrip, logBox])
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
    case failure
  }

  @objc private func profileDidChange() {
    let index = profile.indexOfSelectedItem
    guard profilePlans.indices.contains(index) else { return }
    applyProfilePlan(profilePlans[index])
  }

  @objc private func componentDidChange(_ sender: NSButton) {
    if sender === agentsChoice && agentsChoice.state == .on {
      runtimesChoice.state = .on
    } else if sender === runtimesChoice && runtimesChoice.state == .off {
      agentsChoice.state = .off
    }
    profile.selectItem(at: profilePlans.count)
    updateProfileDetails()
  }

  @objc private func openToolsGuide() {
    guard let url = URL(string: toolsURL) else { return }
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
      lines.append("AI 에이전트: Claude Code · Codex · gajae-code · lazycodex")
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
      ("arrow.down.circle", Brand.cobalt)
    case .success:
      ("checkmark.circle.fill", Brand.mint)
    case .failure:
      ("xmark.circle.fill", .systemRed)
    }
    status.stringValue = message
    status.textColor = presentation.color
    statusIcon.image = Brand.symbol(presentation.symbol)
    statusIcon.contentTintColor = presentation.color
    statusIcon.setAccessibilityLabel(message)
  }

  @objc private func startInstall() {
    guard task == nil else { return }
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
            if ProcessInfo.processInfo.environment["STARTER_KIT_GUI_DISABLE_TERMINAL_OPEN"] != "1"
              && !NSWorkspace.shared.open(handoff)
            {
              try? FileManager.default.removeItem(at: handoff)
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
        if ProcessInfo.processInfo.environment["STARTER_KIT_GUI_EXIT_ON_FINISH"] != "1" {
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
    profile.isEnabled = false
    runtimesChoice.isEnabled = false
    dockerChoice.isEnabled = false
    agentsChoice.isEnabled = false
    dryRun.isEnabled = false
    setStatus("설치 파일을 내려받는 중…", style: .running)
    logEmptyState.isHidden = true
    log.stringValue = ""

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      self?.downloadAndRun(steps: selectedSteps, dryRun: preview)
    }
  }

  private func createTerminalHandoff(steps: [String]) throws -> URL {
    let environment = ProcessInfo.processInfo.environment
    let source = environment["STARTER_KIT_INSTALL_URL"] ?? defaultInstallerURL
    let handoff: URL
    if let path = environment["STARTER_KIT_GUI_HANDOFF_PATH"] {
      handoff = URL(fileURLWithPath: path)
    } else {
      handoff = FileManager.default.temporaryDirectory
        .appendingPathComponent("lazy-starter-kit-\(UUID().uuidString).command")
    }
    let quotedSource = "'" + source.replacingOccurrences(of: "'", with: "'\\''") + "'"
    let selected = steps.joined(separator: ",")
    let script =
      """
      #!/bin/bash
      set -u
      SELF="$0"
      PAYLOAD="$(mktemp -t lazy-starter-kit.XXXXXX)"
      cleanup() {
        /bin/rm -f "$PAYLOAD" "$SELF"
      }
      trap cleanup EXIT

      printf '\\nLazy Starter Kit first-time setup\\n'
      printf 'macOS가 요청할 때 관리자 승인은 이 Terminal 창에서 직접 진행하세요.\\n\\n'
      /usr/bin/curl -fsSL --output "$PAYLOAD" -- \(quotedSource) || exit 1
      /bin/bash "$PAYLOAD" --yes --only \(selected)
      status=$?
      printf '\\n설치기가 종료되었습니다 (status: %s).\\n' "$status"
      exit "$status"

      """
    try script.write(to: handoff, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700],
      ofItemAtPath: handoff.path
    )
    return handoff
  }

  nonisolated private func downloadAndRun(steps: [String], dryRun: Bool) {
    let envURL = ProcessInfo.processInfo.environment["STARTER_KIT_INSTALL_URL"]
    guard let url = URL(string: envURL ?? defaultInstallerURL) else {
      finish(code: 1, message: "설치 주소가 올바르지 않습니다.", action: .retry)
      return
    }
    do {
      let data = try Data(contentsOf: url)
      let payload = FileManager.default.temporaryDirectory
        .appendingPathComponent("lazy-starter-kit-\(UUID().uuidString).sh")
      try data.write(to: payload, options: .atomic)
      run(payload: payload, steps: steps, dryRun: dryRun)
    } catch {
      finish(
        code: 1,
        message: "설치 파일 다운로드 실패: \(error.localizedDescription)",
        action: .retry
      )
    }
  }

  nonisolated private func run(payload: URL, steps: [String], dryRun: Bool) {
    let process = Process()
    let output = Pipe()
    let capture = OutputCapture()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments =
      [payload.path, "--yes", "--only", steps.joined(separator: ",")]
      + (dryRun ? ["--dry-run"] : [])
    process.standardOutput = output
    process.standardError = output

    output.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      let text = String(decoding: data, as: UTF8.self)
      capture.append(text)
      guard let controller = self else { return }
      Task { @MainActor in controller.appendLog(text) }
    }
    process.terminationHandler = { [weak self] completed in
      output.fileHandleForReading.readabilityHandler = nil
      let finalData = output.fileHandleForReading.readDataToEndOfFile()
      if !finalData.isEmpty {
        capture.append(String(decoding: finalData, as: UTF8.self))
      }
      try? FileManager.default.removeItem(at: payload)
      let action: CompletionAction =
        if completed.terminationStatus != 0 {
          .retry
        } else if dryRun {
          .startInstall
        } else {
          .openNewTerminal
        }
      self?.finish(
        code: completed.terminationStatus,
        message: completed.terminationStatus == 0
          ? (
            dryRun
              ? "미리보기 완료 · 실제 설치를 시작할 수 있습니다."
              : "구성 적용 완료 · 새 터미널을 열어 PATH와 프롬프트를 적용하세요."
          )
          : (dryRun
            ? "미리보기가 완료되지 않았습니다. 아래 로그를 확인해 주세요."
            : "설치가 완료되지 않았습니다. 아래 로그를 확인해 주세요."),
        action: action,
        capturedLog: capture.snapshot()
      )
    }

    Task { @MainActor in
      self.task = process
      self.setStatus(
        dryRun ? "변경 내용을 미리 보는 중…" : "구성을 적용하는 중… 창을 닫지 마세요.",
        style: .running
      )
    }
    do {
      try process.run()
    } catch {
      try? FileManager.default.removeItem(at: payload)
      finish(
        code: 1,
        message: "설치기를 시작하지 못했습니다: \(error.localizedDescription)",
        action: .retry
      )
    }
  }

  @MainActor private func appendLog(_ text: String) {
    log.stringValue.append(text)
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

  nonisolated private func finish(
    code: Int32,
    message: String,
    action: CompletionAction,
    guidance: PermissionGuidance? = nil,
    capturedLog: String? = nil
  ) {
    Task { @MainActor in
      self.task = nil
      if let capturedLog {
        self.log.stringValue = capturedLog
        self.log.invalidateIntrinsicContentSize()
        self.log.superview?.layoutSubtreeIfNeeded()
        self.scrollLogToBottom()
      }
      let style: StatusStyle = switch action {
      case .startInstall, .openNewTerminal:
        .success
      case .terminalRequired:
        .ready
      case .administratorRequired, .retry:
        .failure
      }
      self.setStatus(message, style: style)
      switch action {
      case .startInstall:
        self.installButton.title = "이 구성 적용"
        self.dryRun.state = .off
      case .openNewTerminal:
        self.installButton.title = "구성 다시 적용"
      case .terminalRequired:
        self.installButton.title = "Terminal 다시 열기"
      case .administratorRequired, .retry:
        self.installButton.title = "다시 확인"
      }
      self.installButton.isEnabled = true
      self.profile.isEnabled = true
      self.runtimesChoice.isEnabled = true
      self.dockerChoice.isEnabled = true
      self.agentsChoice.isEnabled = true
      self.dryRun.isEnabled = true
      let environment = ProcessInfo.processInfo.environment
      if let resultPath = environment["STARTER_KIT_GUI_RESULT"] {
        do {
          try "\(code)\n\(message)\n\(action.rawValue)\n\(guidance?.rawValue ?? "")\n".write(
            toFile: resultPath,
            atomically: true,
            encoding: .utf8
          )
        } catch {
          self.appendLog("\nQA completion signal failed: \(error.localizedDescription)\n")
        }
      }
      if let logResultPath = environment["STARTER_KIT_GUI_LOG_RESULT"] {
        do {
          try self.log.stringValue.write(
            toFile: logResultPath,
            atomically: true,
            encoding: .utf8
          )
        } catch {
          self.appendLog("\nQA log signal failed: \(error.localizedDescription)\n")
        }
      }
      if environment["STARTER_KIT_GUI_EXIT_ON_FINISH"] == "1" {
        NSApplication.shared.terminate(nil)
      }
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
      dryRun.state = .off
      logEmptyState.isHidden = true
      log.stringValue = "qa-selected:--yes --only prereqs,brew,runtimes,shell,docker,git,agents\nqa-final\n"
      setStatus(
        "구성 적용 완료 · 새 터미널을 열어 PATH와 프롬프트를 적용하세요.",
        style: .success
      )
      installButton.title = "구성 다시 적용"
    case "custom-core":
      profile.selectItem(at: profilePlans.count)
      runtimesChoice.state = .off
      dockerChoice.state = .off
      agentsChoice.state = .off
      updateProfileDetails()
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
      app.delegate = controller
      app.run()
    }
  }
}
