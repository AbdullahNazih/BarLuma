import Foundation

struct ApplicationRemovalPlan {
    static let identifier = "com.anazih.macos-topbar"
    let application: URL
    let dataDirectories: [URL]
    let preferencesFile: URL

    func authorizedApplication(_ selection: URL) throws -> URL {
        guard selection.isFileURL, selection.standardizedFileURL.resolvingSymlinksInPath() == application.resolvingSymlinksInPath() else {
            throw NSError(domain: "BarLuma.Uninstall", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Select the running BarLuma application. Other applications cannot be removed."])
        }
        return selection
    }

    init(application: URL, bundleIdentifier: String, home: URL) throws {
        guard bundleIdentifier == Self.identifier, application.isFileURL,
              application.pathExtension == "app" else {
            throw NSError(domain: "TopBar.Uninstall", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Uninstall is only available from the BarLuma application bundle."])
        }
        self.application = application.standardizedFileURL
        let library = home.appendingPathComponent("Library", isDirectory: true)
        dataDirectories = ["Caches/\(Self.identifier)", "Application Support/\(Self.identifier)",
                           "HTTPStorages/\(Self.identifier)", "Saved Application State/\(Self.identifier).savedState"]
            .map { library.appendingPathComponent($0, isDirectory: true) }
        preferencesFile = library.appendingPathComponent("Preferences/\(Self.identifier).plist")
    }
}
