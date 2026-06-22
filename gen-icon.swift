// Renders the Shell Drive app icon PNGs into an .iconset directory.
// Usage: swift gen-icon.swift <output-iconset-dir>
import AppKit

func drawIcon(px: Int) {
    let size = CGFloat(px)
    let margin = size * 0.085
    let rect = NSRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
    let radius = rect.width * 0.2237   // macOS "squircle"-ish corner

    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.addClip()

    // Match the in-app command badge: coral → pink gradient.
    let grad = NSGradient(colors: [
        NSColor(srgbRed: 1.00, green: 0.52, blue: 0.36, alpha: 1),
        NSColor(srgbRed: 0.97, green: 0.33, blue: 0.47, alpha: 1),
    ])!
    grad.draw(in: rect, angle: -90)

    var cfg = NSImage.SymbolConfiguration(pointSize: size * 0.5, weight: .bold)
    cfg = cfg.applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let base = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: nil),
       let sym = base.withSymbolConfiguration(cfg) {
        let s = sym.size
        let scale = (size * 0.46) / max(s.width, s.height)
        let w = s.width * scale, h = s.height * scale
        let r = NSRect(x: (size - w) / 2, y: (size - h) / 2, width: w, height: h)
        sym.draw(in: r)
    }
}

func writePNG(px: Int, to url: URL) {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(px: px)
    NSGraphicsContext.restoreGraphicsState()
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: url)
    }
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ShellDrive.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

// (filename, pixel size) per Apple's iconset convention.
let specs: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in specs {
    writePNG(px: px, to: URL(fileURLWithPath: out).appendingPathComponent(name))
}
print("Wrote \(specs.count) PNGs to \(out)")
