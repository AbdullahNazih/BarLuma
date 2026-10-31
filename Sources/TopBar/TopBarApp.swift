import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var model: AppModel!
    private var items: [String: NSStatusItem] = [:]
    private var dashboardPanel: NSPanel?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model = AppModel()
        model.onChange = { [weak self] in self?.updateItems() }
        updateItems()
        NotificationCenter.default.addObserver(self, selector: #selector(screenConfigurationChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        if !UserDefaults.standard.bool(forKey: "hasLaunched") {
            showSettings()
            UserDefaults.standard.set(true, forKey: "hasLaunched")
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    private func item(_ key: String, enabled: Bool) -> NSStatusItem? {
        guard enabled else {
            if let existing = items.removeValue(forKey: key) { NSStatusBar.system.removeStatusItem(existing) }
            return nil
        }
        if let existing = items[key] { return existing }
        let created = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        created.autosaveName = "TopBar.\(key)"
        created.button?.target = self
        created.button?.action = #selector(toggleDashboard(_:))
        created.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        items[key] = created
        return created
    }

    private func setTitle(_ title: String, button: NSStatusBarButton?) {
        guard button?.title != title else { return }
        button?.title = title
    }

    private func updateItems() {
        let prefs = model.preferences
        if let button = item("network", enabled: prefs.network)?.button {
            setTitle(" ↓\(DisplayFormat.rate(model.download)) ↑\(DisplayFormat.rate(model.upload)) Mbps ", button: button)
            button.toolTip = "Download / upload · megabits per second\n\(model.interface ?? "No active connection")"
            button.setAccessibilityLabel("Download \(DisplayFormat.rate(model.download)), upload \(DisplayFormat.rate(model.upload)) megabits per second")
        }
        if let button = item("cpu", enabled: prefs.cpu)?.button {
            setTitle(" CPU \(DisplayFormat.percent(model.cpu)) ", button: button)
            button.toolTip = "CPU utilization across all cores"
            button.setAccessibilityLabel("CPU \(DisplayFormat.percent(model.cpu))")
        }
        if let button = item("memory", enabled: prefs.memory)?.button {
            setTitle(" RAM \(DisplayFormat.percent(model.memory?.percent)) ", button: button)
            button.toolTip = "Physical memory used: apps, wired and compressed"
            button.setAccessibilityLabel("Memory \(DisplayFormat.percent(model.memory?.percent))")
        }
        if let button = item("weather", enabled: prefs.weather)?.button {
            let condition = model.weatherCondition
            let symbol = condition?.symbol ?? (prefs.location == nil ? "location.circle" : "cloud.badge.exclamationmark")
            if button.image?.accessibilityDescription != symbol {
                let image = NSImage(systemSymbolName: symbol, accessibilityDescription: symbol)
                image?.isTemplate = true
                button.image = image
            }
            button.imagePosition = .imageLeading
            setTitle(prefs.temperature ? model.weather.flatMap { $0.isStale ? nil : " \($0.temperatureText) " } ?? " — " : "", button: button)
            button.toolTip = "\(prefs.location?.label ?? "Choose a weather location")\n\(condition?.description ?? "Weather unavailable or out of date")\nWeather data by Open-Meteo"
            button.setAccessibilityLabel(button.toolTip)
        }
        if let button = item("settings", enabled: !prefs.network && !prefs.cpu && !prefs.memory && !prefs.weather)?.button {
            button.image = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: "BarLuma settings")
            button.toolTip = "BarLuma · all modules are off"
        }
    }

    @objc private func toggleDashboard(_ sender: NSStatusBarButton) {
        if let panel = dashboardPanel, panel.isVisible { panel.close(); return }
        guard let statusWindow = sender.window,
              let screen = statusWindow.screen ?? NSScreen.main else { return }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 370, height: 500),
                            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "BarLuma"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self
        let dashboard = NSHostingController(rootView: DashboardView(model: model, openSettings: { [weak self] in self?.showSettings() },
                                                                  openAbout: { [weak self] in self?.showAbout() }))
        dashboard.sizingOptions = []
        panel.contentViewController = dashboard
        panel.setContentSize(NSSize(width: 370, height: 500))
        // Size and clamp the entire frame, including the title bar, below the menu bar.
        let anchor = statusWindow.convertToScreen(sender.convert(sender.bounds, to: nil))
        let frame = WindowPlacement.dashboard(size: panel.frame.size, below: anchor, visibleFrame: screen.visibleFrame)
        panel.setFrame(frame, display: false)
        dashboardPanel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    private func showSettings() {
        dashboardPanel?.close()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 590, height: 790), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "BarLuma"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            let settings = NSHostingController(rootView: SettingsView(model: model, locationService: model.locationService,
                                                                                      openDashboard: { [weak self] in self?.showDashboardFromSettings() },
                                                                                      openAbout: { [weak self] in self?.showAbout() },
                                                                                      uninstall: { [weak self] in self?.confirmUninstall() }))
            settings.sizingOptions = []
            window.contentViewController = settings
            window.setContentSize(NSSize(width: 590, height: 790))
            window.center()
            if let screen = window.screen ?? NSScreen.main {
                window.setFrame(WindowPlacement.constrained(window.frame, to: screen.visibleFrame), display: false)
            }
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === dashboardPanel {
            dashboardPanel?.contentViewController = nil
            dashboardPanel = nil
        } else if window === settingsWindow {
            settingsWindow?.contentViewController = nil
            settingsWindow = nil
        } else if window === aboutWindow {
            aboutWindow?.contentViewController = nil
            aboutWindow = nil
        }
    }

    @objc private func screenConfigurationChanged() {
        for window in [dashboardPanel, settingsWindow, aboutWindow].compactMap({ $0 }) {
            guard let screen = window.screen ?? NSScreen.main else { continue }
            window.setFrame(WindowPlacement.constrained(window.frame, to: screen.visibleFrame), display: true)
        }
    }

    private func confirmUninstall() {
        Uninstaller.confirm(on: settingsWindow, prepare: { [weak self] in self?.model.prepareForUninstall() },
                            resume: { [weak self] in self?.model.resumeAfterFailedUninstall() })
    }

    private func showAbout() {
        dashboardPanel?.close()
        if aboutWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 680),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "About BarLuma"
            window.isReleasedWhenClosed = false
            window.delegate = self
            let content = NSHostingController(rootView: AboutView(close: { [weak self] in self?.aboutWindow?.close() }))
            content.sizingOptions = []
            window.contentViewController = content
            window.setContentSize(NSSize(width: 560, height: 680))
            window.center()
            if let screen = window.screen ?? NSScreen.main {
                window.setFrame(WindowPlacement.constrained(window.frame, to: screen.visibleFrame), display: false)
            }
            aboutWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow?.makeKeyAndOrderFront(nil)
    }

    private func showDashboardFromSettings() {
        if let panel = dashboardPanel, panel.isVisible { panel.makeKeyAndOrderFront(nil); return }
        guard let button = items["weather"]?.button ?? items.values.compactMap(\.button).first else { return }
        toggleDashboard(button)
    }
}

@main
@MainActor
struct TopBarApplication {
    static func main() {
        if ProcessInfo.processInfo.arguments.contains("--security-smoke-test") {
            exit(SecurityDiagnostics.run(arguments: ProcessInfo.processInfo.arguments))
        }
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
        withExtendedLifetime(delegate) {}
    }
}
