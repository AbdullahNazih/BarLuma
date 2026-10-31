import AppKit

enum WeatherAppearance {
    static func palette(for symbol: String) -> [NSColor] {
        switch symbol {
        case "sun.max.fill": return [.systemYellow]
        case "moon.stars.fill": return [.systemGray, .systemGray]
        case "cloud.sun.fill": return [.systemGray, .systemYellow]
        case "cloud.moon.fill": return [.systemGray, .systemGray]
        case "cloud.drizzle.fill", "cloud.rain.fill": return [.systemGray, .systemBlue]
        case "cloud.sleet.fill", "cloud.snow.fill": return [.systemGray, .systemCyan]
        case "cloud.bolt.rain.fill": return [.systemGray, .systemBlue]
        default: return [.systemGray]
        }
    }

    static func image(for symbol: String) -> NSImage? {
        var configuration = NSImage.SymbolConfiguration(paletteColors: palette(for: symbol))
        if symbol == "cloud.bolt.rain.fill" { configuration = configuration.applying(.preferringMulticolor()) }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: symbol)?.withSymbolConfiguration(configuration)
        image?.isTemplate = false
        return image
    }
}
