import Foundation
import CoreGraphics

private var failures = 0
private func XCTAssertTrue(_ condition: Bool, file: StaticString = #filePath, line: UInt = #line) {
    if !condition { failures += 1; print("FAIL \(file):\(line)") }
}
private func XCTAssertFalse(_ condition: Bool, file: StaticString = #filePath, line: UInt = #line) { XCTAssertTrue(!condition, file: file, line: line) }
private func XCTAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T, file: StaticString = #filePath, line: UInt = #line) { XCTAssertTrue(lhs == rhs, file: file, line: line) }
private func XCTAssertEqual(_ lhs: Double, _ rhs: Double, accuracy: Double, file: StaticString = #filePath, line: UInt = #line) { XCTAssertTrue(abs(lhs - rhs) <= accuracy, file: file, line: line) }
private func XCTAssertNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) { XCTAssertTrue(value == nil, file: file, line: line) }
private func XCTAssertNotNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) { XCTAssertTrue(value != nil, file: file, line: line) }
private func XCTAssertGreaterThan<T: Comparable>(_ lhs: T, _ rhs: T, file: StaticString = #filePath, line: UInt = #line) { XCTAssertTrue(lhs > rhs, file: file, line: line) }
private func XCTUnwrap<T>(_ value: T?) throws -> T {
    guard let value else { throw NSError(domain: "TopBarChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unexpected nil"]) }
    return value
}
private func assertRejected<T>(_ operation: () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do { _ = try operation(); XCTAssertTrue(false, file: file, line: line) } catch { }
}

final class TopBarTests {
    func testWeatherEndpointsRejectUntrustedDestinations() {
        XCTAssertTrue(WeatherSecurity.allowed(URL(string: "https://api.open-meteo.com/v1/forecast?latitude=0&longitude=0")!))
        XCTAssertTrue(WeatherSecurity.allowed(URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=London")!))
        for raw in ["http://api.open-meteo.com/v1/forecast", "https://api.open-meteo.com.evil.example/v1/forecast",
                    "https://user:password@api.open-meteo.com/v1/forecast", "https://localhost/v1/forecast",
                    "https://api.open-meteo.com:8443/v1/forecast", "https://api.open-meteo.com/v1/forecast#fragment",
                    "file:///etc/passwd", "https://api.open-meteo.com/other"] {
            XCTAssertFalse(WeatherSecurity.allowed(URL(string: raw)!))
        }
    }

    func testWeatherResponsePolicyAndStreamingLimit() throws {
        let good = URL(string: "https://api.open-meteo.com/v1/forecast")!
        let valid = HTTPURLResponse(url: good, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        try WeatherSecurity.validate(valid)
        for response in [
            HTTPURLResponse(url: good, statusCode: 302, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
            HTTPURLResponse(url: good, statusCode: 500, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
            HTTPURLResponse(url: good, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html"])!,
            HTTPURLResponse(url: good, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json", "Content-Length": "131073"])!,
            HTTPURLResponse(url: URL(string: "https://evil.example/")!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        ] { assertRejected { try WeatherSecurity.validate(response) } }
        var body = Data(repeating: 0, count: WeatherSecurity.maximumResponseBytes - 1)
        try WeatherSecurity.append(1, to: &body)
        XCTAssertEqual(body.count, WeatherSecurity.maximumResponseBytes)
        assertRejected { try WeatherSecurity.append(1, to: &body) }
        XCTAssertEqual(body.count, WeatherSecurity.maximumResponseBytes)
    }

    func testWeatherRedirectsAreRefused() {
        let url = URL(string: "https://api.open-meteo.com/v1/forecast")!
        let task = URLSession.shared.dataTask(with: url)
        defer { task.cancel() }
        var called = false
        WeatherRedirectPolicy().urlSession(URLSession.shared, task: task,
            willPerformHTTPRedirection: HTTPURLResponse(url: url, statusCode: 302, httpVersion: nil, headerFields: nil)!,
            newRequest: URLRequest(url: URL(string: "https://evil.example/")!)) { request in
                called = true
                XCTAssertNil(request)
            }
        XCTAssertTrue(called)
    }

    func testUntrustedWeatherNumbersAndCacheCannotCrashDisplay() throws {
        for json in [
            #"{"current":{"temperature_2m":1e200,"is_day":0,"weather_code":0}}"#,
            #"{"current":{"temperature_2m":-101,"is_day":0,"weather_code":0}}"#,
            #"{"current":{"temperature_2m":71,"is_day":0,"weather_code":0}}"#,
            #"{"current":{"temperature_2m":25,"is_day":2,"weather_code":0}}"#,
            #"{"current":{"temperature_2m":25,"is_day":1,"weather_code":999}}"#
        ] {
            let payload = try JSONDecoder().decode(WeatherPayload.self, from: Data(json.utf8))
            assertRejected { try WeatherAPI.snapshot(from: payload, locationID: 1) }
        }
        for value in [Double.greatestFiniteMagnitude, .infinity, -.infinity, .nan] {
            let cached = WeatherSnapshot(locationID: 1, temperature: value, code: 0, isDay: true, fetchedAt: Date())
            XCTAssertFalse(cached.isValid())
            XCTAssertEqual(cached.temperatureText, "—")
        }
        XCTAssertFalse(WeatherSnapshot(locationID: 1, temperature: 25, code: 0, isDay: true, fetchedAt: Date().addingTimeInterval(600)).isValid())
    }

    func testLocationAndPreferencesValidationAndPrivacy() throws {
        let city = WeatherLocation(id: 1, name: "Example city", latitude: 0, longitude: 0, country: "Example", admin1: nil)
        XCTAssertTrue(city.isValid)
        XCTAssertFalse(WeatherLocation(id: 1, name: "Bad\nlabel", latitude: 0, longitude: 0, country: nil, admin1: nil).isValid)
        XCTAssertFalse(WeatherLocation(id: 1, name: "Example", latitude: 91, longitude: 0, country: nil, admin1: nil).isValid)
        XCTAssertFalse(WeatherLocation(id: 1, name: String(repeating: "a", count: 257), latitude: 0, longitude: 0, country: nil, admin1: nil).isValid)
        var prefs = Preferences()
        prefs.location = city
        let auto = Preferences.load(try XCTUnwrap(prefs.persistedData))
        XCTAssertNil(auto.location)
        prefs.automaticLocation = false
        prefs.location = city
        let manual = Preferences.load(try XCTUnwrap(prefs.persistedData))
        XCTAssertEqual(manual.location, city)
        prefs.interval = -1
        XCTAssertEqual(Preferences.load(prefs.persistedData).interval, 3)
        XCTAssertNil(Preferences.load(Data(repeating: 65, count: 65_537)).location)
    }

    func testUninstallRejectsSelectingOtherApplications() throws {
        let plan = try ApplicationRemovalPlan(application: URL(fileURLWithPath: "/tmp/BarLuma.app"),
                                              bundleIdentifier: ApplicationRemovalPlan.identifier, home: URL(fileURLWithPath: "/tmp/home"))
        XCTAssertEqual(try plan.authorizedApplication(URL(fileURLWithPath: "/tmp/BarLuma.app")), plan.application)
        assertRejected { try plan.authorizedApplication(URL(fileURLWithPath: "/tmp/Other.app")) }
        assertRejected { try plan.authorizedApplication(URL(string: "https://example.com/BarLuma.app")!) }
    }
    func testDashboardStaysBelowMenuBarAndInsideScreenMargins() {
        let visible = CGRect(x: 0, y: 70, width: 1440, height: 805)
        for x in [0.0, 720.0, 1430.0] {
            let result = WindowPlacement.dashboard(size: CGSize(width: 370, height: 520),
                                                    below: CGRect(x: x, y: 875, width: 30, height: 25), visibleFrame: visible)
            XCTAssertTrue(visible.insetBy(dx: 12, dy: 12).contains(result))
            XCTAssertTrue(result.maxY <= 863)
        }
    }

    func testSmallAndSecondaryDisplaysConstrainOversizedWindows() {
        let visible = CGRect(x: -1024, y: -800, width: 1024, height: 500)
        let result = WindowPlacement.constrained(CGRect(x: 2000, y: 2000, width: 590, height: 820), to: visible)
        XCTAssertTrue(visible.insetBy(dx: 12, dy: 12).contains(result))
        XCTAssertEqual(result.height, 476)
        XCTAssertEqual(result.width, 590)
    }

    func testUninstallPlanIsLimitedToTopBar() throws {
        let home = URL(fileURLWithPath: "/tmp/topbar-test-home", isDirectory: true)
        let app = URL(fileURLWithPath: "/tmp/topbar-test-home/Applications/MAC OSx - TopBar.app")
        let plan = try ApplicationRemovalPlan(application: app, bundleIdentifier: "com.anazih.macos-topbar", home: home)
        XCTAssertEqual(plan.application, app)
        XCTAssertEqual(plan.dataDirectories.count, 4)
        for path in plan.dataDirectories {
            XCTAssertTrue(path.path.hasPrefix(home.appendingPathComponent("Library").path + "/"))
            XCTAssertTrue(path.lastPathComponent.hasPrefix(ApplicationRemovalPlan.identifier))
        }
        XCTAssertEqual(plan.preferencesFile.lastPathComponent, "com.anazih.macos-topbar.plist")
        XCTAssertTrue((try? ApplicationRemovalPlan(application: app, bundleIdentifier: "com.example.other", home: home)) == nil)
        XCTAssertTrue((try? ApplicationRemovalPlan(application: home, bundleIdentifier: ApplicationRemovalPlan.identifier, home: home)) == nil)
    }

    func testMegabitsUseActualElapsedTime() throws {
        let old = NetworkCounters(interface: "en0", received: 900, sent: 800, timestamp: 10)
        let new = NetworkCounters(interface: "en0", received: 2_000_900, sent: 500_800, timestamp: 12)
        let rates = try XCTUnwrap(new.rates(since: old))
        XCTAssertEqual(rates.download, 8, accuracy: 0.0001)
        XCTAssertEqual(rates.upload, 2, accuracy: 0.0001)
    }

    func testInterfaceSwitchResetAndInvalidIntervalsDoNotProduceSpikes() {
        let old = NetworkCounters(interface: "en0", received: 1000, sent: 1000, timestamp: 10)
        XCTAssertNil(NetworkCounters(interface: "en1", received: 100_000, sent: 100_000, timestamp: 12).rates(since: old))
        XCTAssertNil(NetworkCounters(interface: "en0", received: 0, sent: 0, timestamp: 12).rates(since: old))
        XCTAssertNil(NetworkCounters(interface: "en0", received: 2000, sent: 2000, timestamp: 10).rates(since: old))
    }

    func testCPUUsesAllBusyTicksAndHandlesCounterWrap() throws {
        let old = CPUTicks(user: 100, system: 100, idle: 100, nice: 100)
        let new = CPUTicks(user: 120, system: 110, idle: 160, nice: 110)
        XCTAssertEqual(try XCTUnwrap(new.utilization(since: old)), 40, accuracy: 0.0001)
        XCTAssertNil(old.utilization(since: old))
        let wrapped = CPUTicks(user: 5, system: 0, idle: 10, nice: 0)
        let beforeWrap = CPUTicks(user: UInt32.max - 4, system: 0, idle: 0, nice: 0)
        XCTAssertEqual(try XCTUnwrap(wrapped.utilization(since: beforeWrap)), 50, accuracy: 0.0001)
    }

    func testMemoryPercentageClampsToPhysicalCapacity() {
        XCTAssertEqual(MemoryReading(used: 8, total: 16).percent, 50)
        XCTAssertEqual(MemoryReading(used: 20, total: 16).percent, 100)
        XCTAssertEqual(MemoryReading(used: 0, total: 0).percent, 0)
    }

    func testWeatherCodesRespectNightAndPrecipitation() {
        XCTAssertEqual(WeatherCondition.from(code: 0, isDay: false).symbol, "moon.stars.fill")
        XCTAssertEqual(WeatherCondition.from(code: 2, isDay: false).symbol, "cloud.moon.fill")
        XCTAssertEqual(WeatherCondition.from(code: 0, isDay: true).symbol, "sun.max.fill")
        for code in [61, 63, 65, 80, 81, 82] { XCTAssertEqual(WeatherCondition.from(code: code, isDay: true).description, "Rain") }
        for code in [95, 96, 99] { XCTAssertEqual(WeatherCondition.from(code: code, isDay: false).description, "Thunderstorms") }
        XCTAssertEqual(WeatherCondition.from(code: -1, isDay: true).description, "Unknown conditions")
    }

    func testWeatherPayloadAndCacheRoundTrip() throws {
        let data = Data(#"{"current":{"temperature_2m":28.6,"is_day":0,"weather_code":2}}"#.utf8)
        let payload = try JSONDecoder().decode(WeatherPayload.self, from: data)
        XCTAssertEqual(payload.current.temperature_2m, 28.6)
        let snapshot = WeatherSnapshot(locationID: 1, temperature: 28.6, code: 2, isDay: false, fetchedAt: Date().addingTimeInterval(-3600))
        let decoded = try JSONDecoder().decode(WeatherSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertTrue(decoded.isStale)
        XCTAssertEqual(decoded.condition.symbol, "cloud.moon.fill")
    }

    func testLiveSystemReadersReturnValidValues() throws {
        XCTAssertNotNil(SystemMetrics.cpu())
        let memory = try XCTUnwrap(SystemMetrics.memory())
        XCTAssertGreaterThan(memory.total, 0)
        XCTAssertGreaterThan(memory.used, 0)
        XCTAssertTrue((0...100).contains(memory.percent))
        // A network connection is optional; an available interface must have a monotonic timestamp.
        if let network = SystemMetrics.network() {
            XCTAssertFalse(network.interface.isEmpty)
            XCTAssertGreaterThan(network.timestamp, 0)
        }
    }
}

@main
struct TestRunner {
    static func main() async throws {
        let tests = TopBarTests()
        tests.testWeatherEndpointsRejectUntrustedDestinations()
        try tests.testWeatherResponsePolicyAndStreamingLimit()
        tests.testWeatherRedirectsAreRefused()
        try tests.testUntrustedWeatherNumbersAndCacheCannotCrashDisplay()
        try tests.testLocationAndPreferencesValidationAndPrivacy()
        try tests.testUninstallRejectsSelectingOtherApplications()
        tests.testDashboardStaysBelowMenuBarAndInsideScreenMargins()
        tests.testSmallAndSecondaryDisplaysConstrainOversizedWindows()
        try tests.testUninstallPlanIsLimitedToTopBar()
        try tests.testMegabitsUseActualElapsedTime()
        tests.testInterfaceSwitchResetAndInvalidIntervalsDoNotProduceSpikes()
        try tests.testCPUUsesAllBusyTicksAndHandlesCounterWrap()
        tests.testMemoryPercentageClampsToPhysicalCapacity()
        tests.testWeatherCodesRespectNightAndPrecipitation()
        try tests.testWeatherPayloadAndCacheRoundTrip()
        try tests.testLiveSystemReadersReturnValidValues()
        guard failures == 0 else { exit(1) }
        print("PASS: 16 checks covering malicious weather inputs, endpoint/redirect/size policy, location privacy, uninstall scope, screen margins, metrics and cache handling.")
        if CommandLine.arguments.contains("--live-weather") {
            let location = WeatherLocation(id: 1, name: "Test location", latitude: 0, longitude: 0, country: nil, admin1: nil)
            let weather = try await WeatherAPI.weather(at: location)
            guard weather.isValid(), !(try await WeatherAPI.search("London")).isEmpty else { exit(1) }
            print("PASS: live HTTPS weather and city search through the hardened transport")
        }
    }
}
