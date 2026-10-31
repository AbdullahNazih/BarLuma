import AppKit
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
enum Uninstaller {
    static func confirm(on window: NSWindow?, prepare: @escaping () -> Void, resume: @escaping () -> Void) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Uninstall BarLuma?"
        alert.informativeText = "This removes BarLuma’s login item, saved settings, location and weather cache, moves this application to Trash, and quits."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Uninstall")
        alert.buttons[1].hasDestructiveAction = true
        let handle: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .alertSecondButtonReturn else { return }
            uninstall(prepare: prepare, resume: resume)
        }
        if let window { alert.beginSheetModal(for: window, completionHandler: handle) }
        else { handle(alert.runModal()) }
    }

    private static func uninstall(prepare: () -> Void, resume: () -> Void) {
        do {
            let plan = try ApplicationRemovalPlan(application: Bundle.main.bundleURL,
                                                  bundleIdentifier: Bundle.main.bundleIdentifier ?? "",
                                                  home: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true))
            // App Sandbox requires an explicit user-selected grant to remove the app bundle.
            let picker = NSOpenPanel()
            picker.title = "Authorize BarLuma Removal"
            picker.message = "Select this BarLuma application to allow it to be moved to Trash."
            picker.prompt = "Authorize Removal"
            picker.allowedContentTypes = [.applicationBundle]
            picker.canChooseDirectories = false
            picker.canChooseFiles = true
            picker.allowsMultipleSelection = false
            picker.treatsFilePackagesAsDirectories = false
            picker.directoryURL = plan.application.deletingLastPathComponent()
            picker.nameFieldStringValue = plan.application.lastPathComponent
            guard picker.runModal() == .OK, let selection = picker.url else { return }
            let authorizedApplication = try plan.authorizedApplication(selection)
            let scoped = authorizedApplication.startAccessingSecurityScopedResource()
            defer { if scoped { authorizedApplication.stopAccessingSecurityScopedResource() } }
            if SMAppService.mainApp.status != .notRegistered { try SMAppService.mainApp.unregister() }
            prepare()
            do {
                for directory in plan.dataDirectories where FileManager.default.fileExists(atPath: directory.path) {
                    try FileManager.default.trashItem(at: directory, resultingItemURL: nil)
                }
                try FileManager.default.trashItem(at: authorizedApplication, resultingItemURL: nil)
            } catch {
                resume()
                throw error
            }
            UserDefaults.standard.removePersistentDomain(forName: ApplicationRemovalPlan.identifier)
            UserDefaults.standard.synchronize()
            if FileManager.default.fileExists(atPath: plan.preferencesFile.path) {
                do { try FileManager.default.trashItem(at: plan.preferencesFile, resultingItemURL: nil) }
                catch {
                    showError(title: "BarLuma was moved to Trash", message: "Saved settings were cleared, but macOS could not remove this preferences file: \(plan.preferencesFile.path)\n\n\(error.localizedDescription)")
                }
            }
            NSApp.terminate(nil)
        } catch {
            showError(title: "Couldn’t finish uninstalling BarLuma", message: "\(error.localizedDescription)\n\nYou can try again, or quit BarLuma and move the application to Trash in Finder.")
        }
    }

    private static func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
