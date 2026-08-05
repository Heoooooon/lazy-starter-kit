import AppKit
import Foundation

@MainActor
enum Brand {
  static let mint = NSColor(name: "BrandMint") { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      ? NSColor(calibratedRed: 0.34, green: 0.90, blue: 0.75, alpha: 1)
      : NSColor(calibratedRed: 0.00, green: 0.52, blue: 0.40, alpha: 1)
  }
  static let cobalt = NSColor(name: "BrandCobalt") { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      ? NSColor(calibratedRed: 0.42, green: 0.61, blue: 1, alpha: 1)
      : NSColor(calibratedRed: 0.10, green: 0.35, blue: 0.82, alpha: 1)
  }
  static let surfaceStrong = NSColor(name: "BrandSurfaceStrong") { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      ? NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.10, alpha: 1)
      : NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.98, alpha: 1)
  }

  static func symbol(
    _ name: String,
    pointSize: CGFloat = 14,
    weight: NSFont.Weight = .medium
  ) -> NSImage? {
    let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
      .withSymbolConfiguration(configuration)
  }

  static func appIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let tile = canvas.insetBy(dx: size * 0.07, dy: size * 0.07)
    let radius = size * 0.20
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.38)
    shadow.shadowBlurRadius = size * 0.055
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.025)
    shadow.set()
    NSGradient(
      colors: [
        NSColor(calibratedRed: 0.08, green: 0.14, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 0.025, green: 0.045, blue: 0.075, alpha: 1),
      ]
    )?.draw(in: tilePath, angle: -58)

    NSGraphicsContext.saveGraphicsState()
    let highlight = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
    highlight.lineWidth = max(1, size * 0.012)
    NSColor.white.withAlphaComponent(0.14).setStroke()
    highlight.stroke()
    NSGraphicsContext.restoreGraphicsState()

    if size > 32 {
      drawNode(
        at: NSPoint(x: size * 0.28, y: size * 0.73),
        size: size,
        color: cobalt.withAlphaComponent(0.80)
      )
      drawNode(
        at: NSPoint(x: size * 0.38, y: size * 0.73),
        size: size,
        color: mint.withAlphaComponent(0.65)
      )
      drawNode(
        at: NSPoint(x: size * 0.48, y: size * 0.73),
        size: size,
        color: NSColor.white.withAlphaComponent(0.38)
      )
    }

    if size >= 128 {
      let markShadow = NSShadow()
      markShadow.shadowColor = mint.withAlphaComponent(0.38)
      markShadow.shadowBlurRadius = size * 0.05
      markShadow.shadowOffset = .zero
      markShadow.set()
    }

    let chevron = NSBezierPath()
    chevron.move(to: NSPoint(x: size * 0.30, y: size * 0.60))
    chevron.line(to: NSPoint(x: size * 0.49, y: size * 0.45))
    chevron.line(to: NSPoint(x: size * 0.30, y: size * 0.30))
    chevron.lineWidth = size * 0.075
    chevron.lineCapStyle = .round
    chevron.lineJoinStyle = .round
    mint.setStroke()
    chevron.stroke()

    let line = NSBezierPath()
    line.move(to: NSPoint(x: size * 0.56, y: size * 0.30))
    line.line(to: NSPoint(x: size * 0.72, y: size * 0.30))
    line.lineWidth = size * 0.075
    line.lineCapStyle = .round
    cobalt.setStroke()
    line.stroke()
    return image
  }

  static func writeAppIconPNG(to path: String, size: CGFloat = 1024) throws {
    let image = appIcon(size: size)
    guard
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
    else {
      throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: URL(fileURLWithPath: path), options: .atomic)
  }

  private static func drawNode(at point: NSPoint, size: CGFloat, color: NSColor) {
    let diameter = size * 0.045
    let rect = NSRect(
      x: point.x - diameter / 2,
      y: point.y - diameter / 2,
      width: diameter,
      height: diameter
    )
    color.setFill()
    NSBezierPath(ovalIn: rect).fill()
  }
}
