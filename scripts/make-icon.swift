import AppKit

let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let factor = CGFloat(pixels) / 1024
        let transform = NSAffineTransform()
        transform.scale(by: factor)
        transform.concat()
        let background = NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 210, yRadius: 210)
        NSGradient(starting: NSColor(red: 0.12, green: 0.19, blue: 0.23, alpha: 1), ending: NSColor(red: 0.035, green: 0.065, blue: 0.09, alpha: 1))!.draw(in: background, angle: -90)
        NSColor(white: 1, alpha: 0.10).setStroke()
        background.lineWidth = 3
        background.stroke()
        let heights: [CGFloat] = [175, 305, 440]
        for (index, height) in heights.enumerated() {
            let bar = NSBezierPath(roundedRect: NSRect(x: 250 + CGFloat(index) * 185, y: 265, width: 130, height: height), xRadius: 36, yRadius: 36)
            NSGradient(starting: NSColor(red: 0.28, green: 0.88, blue: 0.68, alpha: 1), ending: NSColor(red: 0.18, green: 0.63, blue: 0.64, alpha: 1))!.draw(in: bar, angle: -90)
        }
        let line = NSBezierPath(roundedRect: NSRect(x: 250, y: 765, width: 500, height: 28), xRadius: 14, yRadius: 14)
        NSColor(white: 1, alpha: 0.82).setFill()
        line.fill()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(destination)/icon_\(size)x\(size)\(suffix).png"))
    }
}
