import AppKit
import Foundation

private let profiles = ["full", "minimal", "work"]
private let defaultInstallerURL =
  "https://raw.githubusercontent.com/Heoooooon/lazy-starter-kit/main/install.sh"

private func selfTest() {
  let contract: [String: Any] = [
    "hasApplicationIcon": true,
    "interfaceVersion": 2,
    "profiles": profiles,
    "supportsAppearanceSnapshots": true,
    "supportsDryRun": true,
    "installerURL": defaultInstallerURL,
  ]
  let data = try! JSONSerialization.data(withJSONObject: contract, options: [.sortedKeys])
  print(String(decoding: data, as: UTF8.self))
}

@MainActor
private final class AdaptiveLogTextView: NSTextView {
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    refreshTextColor()
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    refreshTextColor()
  }

  private func refreshTextColor() {
    guard let storage = textStorage, storage.length > 0 else { return }
    effectiveAppearance.performAsCurrentDrawingAppearance {
      storage.addAttribute(
        .foregroundColor,
        value: NSColor.textColor,
        range: NSRange(location: 0, length: storage.length)
      )
    }
  }
}

@MainActor
private final class InstallerController: NSObject, NSApplicationDelegate {
  private let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 760, height: 680),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
  )
  private let profile = NSPopUpButton(frame: .zero, pullsDown: false)
  private let dryRun = NSButton(checkboxWithTitle: "먼저 미리보기", target: nil, action: nil)
  private let installButton = NSButton(title: "미리보기 시작", target: nil, action: nil)
  private let statusIcon = NSImageView()
  private let status = NSTextField(labelWithString: "준비됨")
  private let log = AdaptiveLogTextView()
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
    if ProcessInfo.processInfo.environment["STARTER_KIT_GUI_AUTOSTART"] == "1" {
      DispatchQueue.main.async { [weak self] in self?.startInstall() }
    }
  }

  private func buildUI() {
    window.title = "Lazy Starter Kit Installer"
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 700, height: 660)
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
        "AI 코딩 환경을 안전하게 준비합니다. 먼저 변경 내용을 확인하고, 준비되면 설치하세요."
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

    profile.addItems(withTitles: ["전체 설치", "최소 설치", "회사 PC용"])
    profile.toolTip = "전체 · 최소 · Docker를 제외한 회사 PC용 중에서 선택합니다."
    profile.controlSize = .large
    profile.setContentHuggingPriority(NSLayoutConstraint.Priority(200), for: .horizontal)

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
      wrappingLabelWithString: "미리보기는 시스템을 변경하지 않습니다. 확인이 끝나면 실제 설치로 전환됩니다."
    )
    setupHint.font = .systemFont(ofSize: 12)
    setupHint.textColor = .tertiaryLabelColor
    let setupContent = NSStackView(views: [profileHeader, controls, setupHint])
    setupContent.orientation = .vertical
    setupContent.alignment = .width
    setupContent.spacing = 11
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
    let trustLabel = NSTextField(labelWithString: "미리보기 기본 · 기존 설정 보존")
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
    log.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    log.textColor = .textColor
    log.backgroundColor = Brand.surfaceStrong
    log.defaultParagraphStyle = logParagraphStyle()
    log.textContainerInset = NSSize(width: 14, height: 13)
    log.string = ""
    logEmptyState.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    logEmptyState.textColor = .labelColor
    logEmptyState.isHidden = false
    logEmptyState.translatesAutoresizingMaskIntoConstraints = false

    let scroll = NSScrollView()
    scroll.documentView = log
    scroll.hasVerticalScroller = true
    scroll.borderType = .noBorder
    scroll.drawsBackground = true
    scroll.backgroundColor = Brand.surfaceStrong
    scroll.wantsLayer = true
    scroll.layer?.cornerRadius = 10
    scroll.layer?.masksToBounds = true
    scroll.translatesAutoresizingMaskIntoConstraints = false
    let logViewport = NSView()
    logViewport.addSubview(scroll)
    logViewport.addSubview(logEmptyState)
    NSLayoutConstraint.activate([
      scroll.leadingAnchor.constraint(equalTo: logViewport.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: logViewport.trailingAnchor),
      scroll.topAnchor.constraint(equalTo: logViewport.topAnchor),
      scroll.bottomAnchor.constraint(equalTo: logViewport.bottomAnchor),
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
    logContent.alignment = .width
    logContent.spacing = 10
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

  private func logParagraphStyle() -> NSParagraphStyle {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 3
    return paragraph
  }

  @objc private func startInstall() {
    guard task == nil else { return }
    installButton.isEnabled = false
    profile.isEnabled = false
    dryRun.isEnabled = false
    setStatus("설치 파일을 내려받는 중…", style: .running)
    logEmptyState.isHidden = true
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
      guard let controller = self else { return }
      Task { @MainActor in controller.appendLog(text) }
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
      self.setStatus(
        dryRun ? "변경 내용을 미리 보는 중…" : "설치 중… 창을 닫지 마세요.",
        style: .running
      )
    }
    do {
      try process.run()
    } catch {
      try? FileManager.default.removeItem(at: payload)
      finish(code: 1, message: "설치기를 시작하지 못했습니다: \(error.localizedDescription)")
    }
  }

  @MainActor private func appendLog(_ text: String) {
    log.textStorage?.append(
      NSAttributedString(string: text, attributes: logAttributes())
    )
    log.scrollToEndOfDocument(nil)
  }

  private func logAttributes() -> [NSAttributedString.Key: Any] {
    [
      .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
      .foregroundColor: NSColor.textColor,
      .paragraphStyle: logParagraphStyle(),
    ]
  }

  nonisolated private func finish(code: Int32, message: String) {
    Task { @MainActor in
      self.task = nil
      self.setStatus(message, style: code == 0 ? .success : .failure)
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

  func saveSnapshot(to path: String, contentSize: NSSize? = nil) throws {
    buildUI()
    if let contentSize { window.setContentSize(contentSize) }
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
