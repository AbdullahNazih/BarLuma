import Foundation

struct Preferences: Codable {
    var network = true
    var cpu = true
    var memory = true
    var weather = true
    var temperature = false
    var automaticLocation = true {
        didSet { if oldValue != automaticLocation { location = nil } }
    }
    var interval: Double = 3
    var location: WeatherLocation?

    mutating func sanitize() {
        if ![2.0, 3.0, 5.0, 10.0].contains(interval) { interval = 3 }
        if location?.isValid == false { location = nil }
    }

    var persistedData: Data? {
        var saved = self
        saved.sanitize()
        // Automatic locations are kept in memory; only explicitly selected cities persist.
        if saved.automaticLocation { saved.location = nil }
        return try? JSONEncoder().encode(saved)
    }

    static func load(_ data: Data?) -> Preferences {
        guard let data, data.count <= 65_536, var result = try? JSONDecoder().decode(Preferences.self, from: data) else { return Preferences() }
        result.sanitize()
        if result.automaticLocation { result.location = nil }
        return result
    }
}
