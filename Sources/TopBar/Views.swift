import SwiftUI

enum DisplayFormat {
    static func rate(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(value >= 100 ? 0 : 1)))
    }
    static func percent(_ value: Double?) -> String { value.map { "\(Int($0.rounded()))%" } ?? "—" }
}

private let mint = Color(red: 0.30, green: 0.83, blue: 0.66)

struct DashboardView: View {
    @ObservedObject var model: AppModel
    var openSettings: () -> Void
    var openAbout: () -> Void

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.xaxis").font(.title2).foregroundStyle(mint)
                Text("BarLuma").font(.title2.weight(.semibold))
                Spacer()
                Label("LIVE", systemImage: "circle.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(mint)
            }
            Text("A little insight. Right at the top.").font(.subheadline).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                MetricRow(title: "Network", symbol: "arrow.up.arrow.down", detail: "↓ \(DisplayFormat.rate(model.download))  ↑ \(DisplayFormat.rate(model.upload)) Mbps", enabled: $model.preferences.network)
                Divider().padding(.leading, 42)
                MetricRow(title: "CPU", symbol: "cpu", detail: DisplayFormat.percent(model.cpu), enabled: $model.preferences.cpu)
                Divider().padding(.leading, 42)
                MetricRow(title: "Memory", symbol: "memorychip", detail: DisplayFormat.percent(model.memory?.percent), enabled: $model.preferences.memory)
                Divider().padding(.leading, 42)
                MetricRow(title: "Weather", symbol: model.weatherCondition?.symbol ?? "cloud", detail: weatherDetail, enabled: $model.preferences.weather)
            }
            .padding(.horizontal, 12).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
            HStack(spacing: 6) {
                Image(systemName: "leaf")
                Text(model.lowPower ? "Low Power Mode · updates every \(Int(model.effectiveInterval))s" : "Updates every \(Int(model.effectiveInterval))s · weather every 15m")
            }.font(.caption).foregroundStyle(.secondary)
            if model.preferences.weather {
                Link("Weather data by Open-Meteo", destination: URL(string: "https://open-meteo.com/")!).font(.caption)
            }
            Divider()
            HStack {
                Button("Settings…", action: openSettings).keyboardShortcut(",")
                Spacer()
                Button("About…", action: openAbout)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }.buttonStyle(.plain).font(.subheadline)
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var weatherDetail: String {
        if model.preferences.location == nil { return "Set up location in Settings" }
        if let weather = model.weather {
            return weather.isStale ? "Out of date · open Settings" : "\(weather.condition.description) · \(weather.temperatureText)"
        }
        return model.refreshingWeather ? "Updating…" : "Weather unavailable"
    }
}

private struct MetricRow: View {
    let title: String
    let symbol: String
    let detail: String
    @Binding var enabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 17)).foregroundStyle(enabled ? mint : .secondary).frame(width: 25)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(enabled ? detail : "Hidden from menu bar").font(.system(size: 11).monospacedDigit()).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Toggle(title, isOn: $enabled).labelsHidden().toggleStyle(.switch).controlSize(.small).tint(mint)
        }.padding(.vertical, 13)
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var locationService: LocationService
    var openDashboard: () -> Void
    var openAbout: () -> Void
    var uninstall: () -> Void
    @State private var query = ""
    @State private var results: [WeatherLocation] = []
    @State private var searching = false
    @State private var searchMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "chart.bar.xaxis").font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(mint).frame(width: 56, height: 56)
                    .background(mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Make room for what matters.").font(.system(size: 23, weight: .semibold, design: .rounded))
                    Text("BarLuma").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(26)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    sectionTitle("YOUR MENU BAR", subtitle: "Choose the information you want to see.")
                    VStack(spacing: 0) {
                        MetricRow(title: "Download & upload", symbol: "arrow.up.arrow.down", detail: "↓ \(DisplayFormat.rate(model.download))  ↑ \(DisplayFormat.rate(model.upload)) Mbps", enabled: $model.preferences.network)
                        Divider().padding(.leading, 42)
                        MetricRow(title: "CPU utilization", symbol: "cpu", detail: "\(DisplayFormat.percent(model.cpu)) of total processor capacity", enabled: $model.preferences.cpu)
                        Divider().padding(.leading, 42)
                        MetricRow(title: "RAM utilization", symbol: "memorychip", detail: memoryDetail, enabled: $model.preferences.memory)
                        Divider().padding(.leading, 42)
                        MetricRow(title: "Local weather", symbol: model.weatherCondition?.symbol ?? "cloud.sun", detail: "Sun, moon, clouds, rain and more", enabled: $model.preferences.weather)
                    }.padding(.horizontal, 16).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))

                    if model.preferences.weather {
                        sectionTitle("OUTSIDE, AT A GLANCE", subtitle: "Weather follows your location, with your permission.")
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle("Use my location automatically", isOn: $model.preferences.automaticLocation).tint(mint)
                            if model.preferences.automaticLocation {
                                Text(locationService.status).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                HStack {
                                    Button("Update location") { locationService.request(force: true) }
                                    Button("Location Services…") {
                                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                                    }
                                }.controlSize(.small)
                            } else {
                                HStack {
                                    TextField("Search for a city", text: $query).textFieldStyle(.roundedBorder).onSubmit(search)
                                    Button(action: search) {
                                        if searching { ProgressView().controlSize(.small) } else { Text("Search") }
                                    }.disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || searching)
                                }
                                if let searchMessage { Text(searchMessage).font(.caption).foregroundStyle(.secondary) }
                                ForEach(results) { location in
                                    Button {
                                        model.preferences.location = location
                                        results = []; searchMessage = nil
                                    } label: {
                                        HStack { Image(systemName: "mappin.circle"); Text(location.label); Spacer(); Image(systemName: "plus.circle") }
                                            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                    }.buttonStyle(.plain).padding(.vertical, 4)
                                }
                            }
                            if let location = model.preferences.location {
                                HStack(alignment: .top) {
                                    Image(systemName: model.weatherCondition?.symbol ?? "cloud").font(.title2).foregroundStyle(mint)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(location.label).fontWeight(.medium)
                                        if let weather = model.weather {
                                            Text("\(weather.condition.description) · \(weather.temperatureText)\(weather.isStale ? " · Out of date" : "")")
                                            Text("Updated \(weather.fetchedAt.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                                        } else { Text(model.refreshingWeather ? "Fetching weather…" : "Waiting for weather").foregroundStyle(.secondary) }
                                    }
                                    Spacer()
                                    Button { model.refreshWeather(force: true) } label: { Image(systemName: "arrow.clockwise") }
                                        .disabled(model.refreshingWeather).help("Refresh weather")
                                }.font(.subheadline)
                            }
                            if let error = model.weatherError { Text(error).font(.caption).foregroundStyle(.secondary) }
                            Toggle("Show temperature beside the weather icon", isOn: $model.preferences.temperature).font(.subheadline).tint(mint)
                            Link("Weather data by Open-Meteo · CC BY 4.0", destination: URL(string: "https://open-meteo.com/")!).font(.caption)
                            Text("Rounded coordinates are sent to Open-Meteo for weather and Apple for city lookup. Automatic locations stay in memory. Turning weather off stops these requests.").font(.caption).foregroundStyle(.secondary)
                        }.padding(16).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
                    }

                    sectionTitle("SMALL FOOTPRINT", subtitle: "Simple controls for a quieter background app.")
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Label("Refresh interval", systemImage: "timer")
                            Spacer()
                            Picker("Refresh interval", selection: $model.preferences.interval) {
                                Text("2 seconds").tag(2.0); Text("3 seconds").tag(3.0)
                                Text("5 seconds").tag(5.0); Text("10 seconds").tag(10.0)
                            }.labelsHidden().frame(width: 145)
                        }
                        Toggle("Open at login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) })).tint(mint)
                        if let error = model.loginError { Text(error).font(.caption).foregroundStyle(.secondary) }
                        Label("Pauses during sleep. Slows to 10 seconds in Low Power Mode.", systemImage: "leaf").font(.caption).foregroundStyle(.secondary)
                    }.padding(16).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
                    Text("Mbps = megabits per second. Network shows traffic through your active connection, including local network traffic. RAM includes app, wired and compressed memory.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }.padding(26)
            }
            Divider()
            HStack {
                Text("BarLuma \(AppInformation.version)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("About…", action: openAbout).controlSize(.small)
                Button("Dashboard", action: openDashboard).controlSize(.small)
                Button("Uninstall BarLuma…", role: .destructive, action: uninstall).controlSize(.small)
                Button("Quit BarLuma") { NSApp.terminate(nil) }.controlSize(.small)
            }.padding(.horizontal, 26).padding(.vertical, 14)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear { searchTask?.cancel(); searchTask = nil; searching = false }
    }

    private var memoryDetail: String {
        guard let memory = model.memory else { return "Measuring physical memory…" }
        let used = Double(memory.used) / 1_073_741_824
        let total = Double(memory.total) / 1_073_741_824
        return "\(DisplayFormat.percent(memory.percent)) · \(used.formatted(.number.precision(.fractionLength(1)))) of \(Int(total)) GB"
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 10, weight: .bold)).tracking(1.7).foregroundStyle(.secondary)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func search() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else { return }
        searchTask?.cancel()
        searching = true; searchMessage = nil
        searchTask = Task { @MainActor in
            do {
                let matches = try await WeatherAPI.search(term)
                guard !Task.isCancelled else { return }
                results = matches
                searchMessage = matches.isEmpty ? "No cities found. Try a nearby city." : nil
            } catch {
                guard !Task.isCancelled else { return }
                results = []; searchMessage = "Couldn’t search cities. Check your connection and try again."
            }
            searching = false
        }
    }
}
