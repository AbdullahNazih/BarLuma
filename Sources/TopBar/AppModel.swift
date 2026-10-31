import AppKit
import Combine
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published var preferences: Preferences {
        didSet {
            if let data = preferences.persistedData { UserDefaults.standard.set(data, forKey: "preferences.v1") }
            if preferences.automaticLocation || !preferences.weather { UserDefaults.standard.removeObject(forKey: "weather.v1") }
            if oldValue.network != preferences.network { lastNetwork = nil; download = nil; upload = nil }
            if oldValue.cpu != preferences.cpu { lastCPU = nil; cpu = nil }
            configureTimer()
            if oldValue.weather != preferences.weather || oldValue.location?.id != preferences.location?.id {
                weatherTask?.cancel()
                weatherTask = nil
                weatherError = nil
                if oldValue.location?.id != preferences.location?.id { weather = nil }
                configureWeather()
            }
            if oldValue.automaticLocation != preferences.automaticLocation || oldValue.weather != preferences.weather {
                locationService.configure(enabled: preferences.weather && preferences.automaticLocation)
            }
            onChange?()
        }
    }
    @Published private(set) var download: Double?
    @Published private(set) var upload: Double?
    @Published private(set) var cpu: Double?
    @Published private(set) var memory: MemoryReading?
    @Published private(set) var interface: String?
    @Published private(set) var weather: WeatherSnapshot?
    @Published private(set) var weatherError: String?
    @Published private(set) var refreshingWeather = false
    @Published private(set) var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    @Published var loginError: String?
    var onChange: (() -> Void)?
    let locationService = LocationService()
    private var timer: Timer?
    private var weatherTimer: Timer?
    private var weatherTask: Task<Void, Never>?
    private var lastCPU: CPUTicks?
    private var lastNetwork: NetworkCounters?
    private var sleeping = false
    private var observers: [NSObjectProtocol] = []

    var effectiveInterval: Double { lowPower ? max(10, preferences.interval) : preferences.interval }
    var hasMetrics: Bool { preferences.network || preferences.cpu || preferences.memory }
    var weatherCondition: WeatherCondition? { weather.flatMap { $0.isStale ? nil : $0.condition } }

    init() {
        let defaults = UserDefaults.standard
        preferences = Preferences.load(defaults.data(forKey: "preferences.v1"))
        if let data = defaults.data(forKey: "weather.v1"), data.count <= 65_536 {
            weather = try? JSONDecoder().decode(WeatherSnapshot.self, from: data)
        }
        if preferences.automaticLocation || !preferences.weather || weather?.isValid() != true || weather?.locationID != preferences.location?.id { weather = nil }
        if weather == nil { defaults.removeObject(forKey: "weather.v1") }
        if let data = preferences.persistedData { defaults.set(data, forKey: "preferences.v1") }
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.suspend() }
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.resume() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                self?.configureTimer()
            }
        })
        sample()
        configureTimer()
        configureWeather()
        locationService.onLocation = { [weak self] location in
            guard let self, self.preferences.automaticLocation, self.preferences.weather else { return }
            if self.preferences.location != location { self.preferences.location = location }
        }
        locationService.configure(enabled: preferences.weather && preferences.automaticLocation)
    }

    private func configureTimer() {
        timer?.invalidate()
        timer = nil
        guard !sleeping, hasMetrics else { return }
        // One coalescible timer for all enabled local modules.
        let next = Timer(timeInterval: effectiveInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        next.tolerance = effectiveInterval * 0.3
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    private func sample() {
        if preferences.cpu {
            if let ticks = SystemMetrics.cpu() {
                cpu = lastCPU.flatMap { ticks.utilization(since: $0) }
                lastCPU = ticks
            } else { cpu = nil; lastCPU = nil }
        }
        if preferences.memory { memory = SystemMetrics.memory() }
        if preferences.network {
            if let counters = SystemMetrics.network() {
                let rates = lastNetwork.flatMap { counters.rates(since: $0) }
                download = rates?.download
                upload = rates?.upload
                interface = counters.interface
                lastNetwork = counters
            } else {
                lastNetwork = nil; download = nil; upload = nil; interface = nil
            }
        }
        onChange?()
    }

    private func configureWeather() {
        weatherTimer?.invalidate()
        weatherTimer = nil
        guard !sleeping, preferences.weather, preferences.location != nil else {
            refreshingWeather = false
            onChange?()
            return
        }
        refreshWeather()
        let next = Timer(timeInterval: 900, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshWeather() }
        }
        next.tolerance = 90
        RunLoop.main.add(next, forMode: .common)
        weatherTimer = next
    }

    func refreshWeather(force: Bool = false) {
        if preferences.weather && preferences.automaticLocation { locationService.request() }
        guard !sleeping, preferences.weather, let location = preferences.location, weatherTask == nil else { return }
        if !force, let weather, weather.locationID == location.id, Date().timeIntervalSince(weather.fetchedAt) < 900 { return }
        refreshingWeather = true
        weatherError = nil
        weatherTask = Task { [weak self] in
            do {
                let snapshot = try await WeatherAPI.weather(at: location)
                guard !Task.isCancelled, let self, self.preferences.weather, self.preferences.location?.id == location.id else { return }
                self.weather = snapshot
                if !self.preferences.automaticLocation, let data = try? JSONEncoder().encode(snapshot) {
                    UserDefaults.standard.set(data, forKey: "weather.v1")
                }
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.weatherError = "Weather unavailable. Will retry at the next refresh."
            }
            guard !Task.isCancelled, let self else { return }
            self.refreshingWeather = false
            self.weatherTask = nil
            self.onChange?()
        }
    }

    private func suspend() {
        sleeping = true
        timer?.invalidate(); weatherTimer?.invalidate()
        weatherTask?.cancel(); weatherTask = nil; refreshingWeather = false
        lastCPU = nil; lastNetwork = nil
    }

    func prepareForUninstall() {
        suspend()
        locationService.configure(enabled: false)
    }

    func resumeAfterFailedUninstall() {
        loginEnabled = SMAppService.mainApp.status == .enabled
        locationService.configure(enabled: preferences.weather && preferences.automaticLocation)
        resume()
    }

    private func resume() {
        sleeping = false
        sample()
        configureTimer()
        configureWeather()
        if preferences.weather && preferences.automaticLocation { locationService.request() }
    }

    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            loginError = SMAppService.mainApp.status == .requiresApproval ? "Allow BarLuma in System Settings → General → Login Items." : nil
        } catch {
            loginEnabled = SMAppService.mainApp.status == .enabled
            loginError = "Could not update login setting. Move the app to Applications and try again."
        }
    }
}
