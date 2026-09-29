import AppKit

// Generates AppIcon.iconset (all required sizes) for `iconutil`.
// Run: swift scripts/make-icon.swift && iconutil -c icns AppIcon.iconset -o Resources/AppIcon.icns

let outDir = "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func draw(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    // Rounded-square tile with a vertical gradient.
    let tileRect = NSRect(x: 0, y: 0, width: s, height: s)
    let tile = NSBezierPath(roundedRect: tileRect, xRadius: s * 0.225, yRadius: s * 0.225)
    tile.addClip()
    let gradient = NSGradient(colors: [
        NSColor(calibratedWhite: 0.16, alpha: 1),
        NSColor(calibratedWhite: 0.04, alpha: 1),
    ])!
    gradient.draw(in: tileRect, angle: -90)

    // The island: a black capsule.
    let capW = s * 0.72
    let capH = s * 0.22
    let capRect = NSRect(x: (s - capW) / 2, y: (s - capH) / 2, width: capW, height: capH)
    let capsule = NSBezierPath(roundedRect: capRect, xRadius: capH / 2, yRadius: capH / 2)
    NSColor.black.setFill()
    capsule.fill()

    // Two accent dots (green + white), echoing the Dynamic Island indicators.
    func dot(cx: CGFloat, color: NSColor) {
        let r = capH * 0.18
        let rect = NSRect(x: cx - r, y: s / 2 - r, width: r * 2, height: r * 2)
        color.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }
    dot(cx: s * 0.315, color: NSColor(calibratedRed: 0.30, green: 0.85, blue: 0.55, alpha: 1))
    dot(cx: s * 0.685, color: .white)

    image.unlockFocus()
    return image
}

func save(_ image: NSImage, name: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else {
        print("failed to encode \(name)")
        return
    }
    try? data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, size) in sizes {
    save(draw(size: size), name: name)
}
print("iconset written to \(outDir)")
