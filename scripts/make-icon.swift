// Renders the app icon — the menu bar robot, white on a graphite rounded
// square — into App/AgentUsage/Assets.xcassets/AppIcon.appiconset, plus a
// 512 px copy for the README. Run from the repo root: swift scripts/make-icon.swift
import AppKit

let robotSVG = URL(fileURLWithPath: "Sources/AgentUsageUI/Resources/Logos/robot.svg")
let iconSet = URL(fileURLWithPath: "App/AgentUsage/Assets.xcassets/AppIcon.appiconset")
let readmeIcon = URL(fileURLWithPath: "docs/images/icon.png")

/// Apple's macOS icon grid: an 824 pt rounded square centred on 1024.
let canvas: CGFloat = 1024
let tile: CGFloat = 824
let cornerRadius: CGFloat = 185
/// The robot's share of the tile.
let glyphScale: CGFloat = 0.56

func renderIcon(pixels: Int) throws -> Data {
    guard let robot = NSImage(contentsOf: robotSVG) else {
        throw NSError(domain: "make-icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "cannot read \(robotSVG.path)"])
    }
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: canvas, height: canvas)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    let inset = (canvas - tile) / 2
    let tileRect = NSRect(x: inset, y: inset, width: tile, height: tile)
    let shape = NSBezierPath(roundedRect: tileRect, xRadius: cornerRadius, yRadius: cornerRadius)

    // Soft drop shadow, as on Apple's own icons.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 28
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Graphite body, lighter at the top.
    NSGradient(
        starting: NSColor(srgbRed: 0.24, green: 0.24, blue: 0.27, alpha: 1),
        ending: NSColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: 1)
    )?.draw(in: shape, angle: -90)

    // A hairline highlight along the edge.
    NSColor.white.withAlphaComponent(0.12).setStroke()
    let rim = NSBezierPath(roundedRect: tileRect.insetBy(dx: 2, dy: 2), xRadius: cornerRadius - 2, yRadius: cornerRadius - 2)
    rim.lineWidth = 4
    rim.stroke()

    // The robot, white.
    let side = tile * glyphScale
    let glyphRect = NSRect(x: (canvas - side) / 2, y: (canvas - side) / 2 - tile * 0.01, width: side, height: side)
    let white = NSImage(size: glyphRect.size, flipped: false) { rect in
        robot.draw(in: rect)
        NSColor.white.set()
        rect.fill(using: .sourceAtop)
        return true
    }
    white.draw(in: glyphRect)

    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "make-icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "PNG encoding failed"])
    }
    return png
}

// macOS wants 16, 32, 128, 256 and 512 pt, each at 1x and 2x.
let points = [16, 32, 128, 256, 512]
try FileManager.default.createDirectory(at: iconSet, withIntermediateDirectories: true)
var images: [[String: String]] = []
for point in points {
    for scale in [1, 2] {
        let name = "icon_\(point)x\(point)\(scale == 2 ? "@2x" : "").png"
        try renderIcon(pixels: point * scale).write(to: iconSet.appending(path: name))
        images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(point)x\(point)"])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: iconSet.appending(path: "Contents.json"))
try JSONSerialization.data(withJSONObject: ["info": ["author": "xcode", "version": 1]], options: .prettyPrinted)
    .write(to: iconSet.deletingLastPathComponent().appending(path: "Contents.json"))
try renderIcon(pixels: 512).write(to: readmeIcon)
print("wrote \(iconSet.path) and \(readmeIcon.path)")
