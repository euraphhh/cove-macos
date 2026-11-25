// Renders the app icon to Resources/AppIcon.icns. Run: swift scripts/make-icon.swift
import AppKit

func render(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    let s = size / 1024
    // macOS icon grid: 824pt rounded square centered on a 1024 canvas.
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 24 * s
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    shadow.set()
    NSGradient(colors: [NSColor(red: 0.17, green: 0.18, blue: 0.30, alpha: 1),
                        NSColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1)])?.draw(in: tilePath, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    // The island pill.
    let pill = NSRect(x: 222 * s, y: 582 * s, width: 580 * s, height: 160 * s)
    NSColor.black.setFill()
    NSBezierPath(roundedRect: pill, xRadius: 80 * s, yRadius: 80 * s).fill()
    NSColor.white.withAlphaComponent(0.10).setStroke()
    let rim = NSBezierPath(roundedRect: pill.insetBy(dx: 1.5 * s, dy: 1.5 * s), xRadius: 78 * s, yRadius: 78 * s)
    rim.lineWidth = 3 * s
    rim.stroke()

    // Album art on the left.
    let art = NSRect(x: 262 * s, y: 617 * s, width: 90 * s, height: 90 * s)
    NSGradient(colors: [NSColor(red: 1, green: 0.45, blue: 0.35, alpha: 1),
                        NSColor(red: 0.85, green: 0.2, blue: 0.6, alpha: 1)])?
        .draw(in: NSBezierPath(roundedRect: art, xRadius: 24 * s, yRadius: 24 * s), angle: -45)

    // Equalizer bars on the right.
    let heights: [CGFloat] = [46, 86, 62, 96, 54]
    let barColor = NSColor(red: 1, green: 0.55, blue: 0.5, alpha: 1)
    barColor.setFill()
    for (i, h) in heights.enumerated() {
        let x = (612 + CGFloat(i) * 30) * s
        let bar = NSRect(x: x, y: (662 - h / 2) * s, width: 16 * s, height: h * s)
        NSBezierPath(roundedRect: bar, xRadius: 8 * s, yRadius: 8 * s).fill()
    }
    img.unlockFocus()
    return img
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = CGFloat(base * scale)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px), bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        render(size: px).draw(in: NSRect(x: 0, y: 0, width: px, height: px))
        NSGraphicsContext.restoreGraphicsState()
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try! p.run(); p.waitUntilExit()
let preview = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cove-icon-preview.png")
try? fm.removeItem(at: preview)
try? fm.copyItem(at: iconset.appendingPathComponent("icon_512x512@2x.png"),
                 to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cove-icon-preview.png"))
print("Wrote \(out.path)")
