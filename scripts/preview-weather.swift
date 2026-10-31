import AppKit

@main
struct PreviewWeather {
    static func main() throws {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 720, pixelsHigh: 280,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let symbols = ["sun.max.fill", "moon.stars.fill", "cloud.sun.fill", "cloud.rain.fill", "cloud.bolt.rain.fill", "cloud.snow.fill"]
        let labels = ["Sun", "Moon", "Partly cloudy", "Rain", "Storm", "Snow"]
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        for (row, appearanceName) in [NSAppearance.Name.aqua, .darkAqua].enumerated() {
            NSAppearance(named: appearanceName)!.performAsCurrentDrawingAppearance {
                let y = CGFloat(row * 140)
                (row == 0 ? NSColor.white : NSColor(white: 0.13, alpha: 1)).setFill()
                NSBezierPath(rect: NSRect(x: 0, y: y, width: 720, height: 140)).fill()
                for (column, symbol) in symbols.enumerated() {
                    WeatherAppearance.image(for: symbol)?.draw(in: NSRect(x: column * 120 + 34, y: Int(y) + 52, width: 52, height: 52))
                    let text = NSAttributedString(string: labels[column], attributes: [.font: NSFont.systemFont(ofSize: 12),
                        .foregroundColor: row == 0 ? NSColor.black : NSColor.white])
                    text.draw(at: NSPoint(x: CGFloat(column * 120) + (120 - text.size().width) / 2, y: y + 20))
                }
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
}
