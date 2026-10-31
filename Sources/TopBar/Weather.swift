import Foundation

struct WeatherLocation: Codable, Equatable, Identifiable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?
    var isValid: Bool {
        (0...2_000_000_000).contains(id) && latitude.isFinite && longitude.isFinite &&
        (-90...90).contains(latitude) && (-180...180).contains(longitude) &&
        WeatherSecurity.validLabel(name) && (country.map(WeatherSecurity.validLabel) ?? true) &&
        (admin1.map(WeatherSecurity.validLabel) ?? true)
    }
    var label: String { [name, admin1, country].compactMap { $0 }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.joined(separator: ", ") }
}

struct WeatherCondition: Equatable {
    let symbol: String
    let description: String

    static func from(code: Int, isDay: Bool) -> WeatherCondition {
        switch code {
        case 0: return .init(symbol: isDay ? "sun.max.fill" : "moon.stars.fill", description: isDay ? "Clear skies" : "Clear night")
        case 1, 2: return .init(symbol: isDay ? "cloud.sun.fill" : "cloud.moon.fill", description: "Partly cloudy")
        case 3: return .init(symbol: "cloud.fill", description: "Overcast")
        case 45, 48: return .init(symbol: "cloud.fog.fill", description: "Fog")
        case 51, 53, 55: return .init(symbol: "cloud.drizzle.fill", description: "Drizzle")
        case 56, 57, 66, 67: return .init(symbol: "cloud.sleet.fill", description: "Freezing rain")
        case 61, 63, 65, 80, 81, 82: return .init(symbol: "cloud.rain.fill", description: "Rain")
        case 71, 73, 75, 77, 85, 86: return .init(symbol: "cloud.snow.fill", description: "Snow")
        case 95, 96, 99: return .init(symbol: "cloud.bolt.rain.fill", description: "Thunderstorms")
        default: return .init(symbol: "questionmark.circle", description: "Unknown conditions")
        }
    }
}

struct WeatherPayload: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let is_day: Int
        let weather_code: Int
    }
    let current: Current
}

struct WeatherSnapshot: Codable {
    let locationID: Int
    let temperature: Double
    let code: Int
    let isDay: Bool
    let fetchedAt: Date
    var temperatureText: String { WeatherSecurity.validTemperature(temperature) ? "\(Int(temperature.rounded()))°C" : "—" }
    func isValid(at now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince(fetchedAt)
        return locationID >= 0 && WeatherSecurity.validTemperature(temperature) && WeatherSecurity.validCodes.contains(code) &&
               age.isFinite && age >= -300 && age <= 86_400
    }
    var condition: WeatherCondition { .from(code: code, isDay: isDay) }
    var isStale: Bool { !isValid() || Date().timeIntervalSince(fetchedAt) > 1800 }
}

enum WeatherAPI {
    static func fetch<T: Decodable>(_ type: T.Type, url: URL) async throws -> T {
        let data = try await SecureWeatherTransport.data(from: url)
        return try JSONDecoder().decode(type, from: data)
    }

    static func search(_ query: String) async throws -> [WeatherLocation] {
        guard (2...100).contains(query.count), WeatherSecurity.validLabel(query) else { throw URLError(.badURL) }
        struct Results: Decodable { let results: [WeatherLocation]? }
        var parts = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        parts.queryItems = [.init(name: "name", value: query), .init(name: "count", value: "6"), .init(name: "language", value: "en"), .init(name: "format", value: "json")]
        let results = try await fetch(Results.self, url: parts.url!).results ?? []
        guard results.count <= 6, results.allSatisfy(\.isValid) else { throw URLError(.cannotParseResponse) }
        return results
    }

    static func weather(at location: WeatherLocation) async throws -> WeatherSnapshot {
        guard location.isValid else { throw URLError(.badURL) }
        var parts = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        parts.queryItems = [.init(name: "latitude", value: String(location.latitude)),
                            .init(name: "longitude", value: String(location.longitude)),
                            .init(name: "current", value: "temperature_2m,is_day,weather_code")]
        let payload = try await fetch(WeatherPayload.self, url: parts.url!)
        return try snapshot(from: payload, locationID: location.id)
    }

    static func snapshot(from payload: WeatherPayload, locationID: Int) throws -> WeatherSnapshot {
        guard WeatherSecurity.validTemperature(payload.current.temperature_2m),
              [0, 1].contains(payload.current.is_day), WeatherSecurity.validCodes.contains(payload.current.weather_code) else {
            throw URLError(.cannotParseResponse)
        }
        return WeatherSnapshot(locationID: locationID, temperature: payload.current.temperature_2m,
                               code: payload.current.weather_code, isDay: payload.current.is_day == 1, fetchedAt: Date())
    }
}
