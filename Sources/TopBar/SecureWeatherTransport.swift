import Foundation

enum WeatherSecurity {
    static let maximumResponseBytes = 128 * 1024
    static let validCodes: Set<Int> = [0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99]

    static func allowed(_ url: URL) -> Bool {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "https", parts.user == nil, parts.password == nil,
              parts.fragment == nil, parts.port == nil || parts.port == 443 else { return false }
        return (parts.host == "api.open-meteo.com" && parts.path == "/v1/forecast") ||
               (parts.host == "geocoding-api.open-meteo.com" && parts.path == "/v1/search")
    }

    static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let url = http.url, allowed(url),
              let mime = http.mimeType?.lowercased(), mime == "application/json" || mime == "application/geo+json" else {
            throw URLError(.badServerResponse)
        }
        guard response.expectedContentLength <= maximumResponseBytes else { throw URLError(.dataLengthExceedsMaximum) }
    }

    static func append(_ byte: UInt8, to data: inout Data) throws {
        guard data.count < maximumResponseBytes else { throw URLError(.dataLengthExceedsMaximum) }
        data.append(byte)
    }

    static func validTemperature(_ value: Double) -> Bool { value.isFinite && (-100...70).contains(value) }

    static func validLabel(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf8.count <= 256 &&
        !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    }
}

/// Refuse all redirects; the two fixed HTTPS API endpoints do not require them.
/// Default URLSession trust handling remains intact. No authentication challenges are overridden.
final class WeatherRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

enum SecureWeatherTransport {
    private static let redirects = WeatherRedirectPolicy()
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        config.urlCache = nil
        config.urlCredentialStorage = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpMaximumConnectionsPerHost = 2
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        return URLSession(configuration: config)
    }()

    static func data(from url: URL) async throws -> Data {
        guard WeatherSecurity.allowed(url) else { throw URLError(.unsupportedURL) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request, delegate: redirects)
        defer { bytes.task.cancel() }
        try WeatherSecurity.validate(response)
        guard response.url == url else { throw URLError(.redirectToNonExistentLocation) }
        var data = Data()
        // Enforce the limit on decoded response bytes, including chunked/compressed bodies.
        for try await byte in bytes {
            try Task.checkCancellation()
            try WeatherSecurity.append(byte, to: &data)
        }
        return data
    }
}
