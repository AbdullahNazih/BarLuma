import SwiftUI

enum AppInformation {
    static let name = "BarLuma"
    static let enterpriseEmail = "Abdullah.n.sy@gmail.com"
    static let repositoryURL = URL(string: "https://github.com/AbdullahNazih/BarLuma")!
    static let releasesURL = repositoryURL.appendingPathComponent("releases").appendingPathComponent("latest")
    static let description = "A lightweight macOS menu bar companion for download and upload speeds in Mbps, CPU and RAM utilization, and local weather. Choose which readings appear, use automatic or selected weather locations, and adjust the refresh interval to suit your Mac."
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }
    static var licenseNotice: String {
        guard let url = Bundle.main.url(forResource: "License", withExtension: "txt"),
              let notice = try? String(contentsOf: url, encoding: .utf8) else {
            return "Free for personal, non-commercial use. Enterprise and commercial use requires separate written licensing terms. Contact \(enterpriseEmail) for the complete license notice."
        }
        return notice
    }
    static var privacyNotice: String {
        guard let url = Bundle.main.url(forResource: "Privacy", withExtension: "md"),
              let notice = try? String(contentsOf: url, encoding: .utf8) else { return "See PRIVACY.md in the source distribution." }
        return notice
    }
}

struct AboutView: View {
    var close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable().interpolation(.high).frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(AppInformation.name).font(.title2.weight(.semibold))
                        Text("Version \(AppInformation.version)").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Text(AppInformation.description).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label("Free for personal, non-commercial use", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.medium)).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 14) {
                        Link("Check for Updates…", destination: AppInformation.releasesURL)
                            .help("Open the latest GitHub release. Updates are installed manually.")
                        Link("GitHub project", destination: AppInformation.repositoryURL)
                    }.font(.subheadline)
                    Text("On GitHub, choose Watch → Custom → Releases to receive update notifications.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Enterprise licensing").font(.subheadline.weight(.semibold))
                    Text("For business or organizational use, contact:").font(.subheadline).foregroundStyle(.secondary)
                    Link(AppInformation.enterpriseEmail, destination: URL(string: "mailto:\(AppInformation.enterpriseEmail)?subject=BarLuma%20Enterprise%20Licensing")!)
                        .font(.subheadline).help("Email the developer about enterprise licensing")
                }
            }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("LICENSE & NOTICES").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(.secondary)
                    DisclosureGroup("Privacy & permissions") {
                        Text(AppInformation.privacyNotice).font(.system(size: 12)).lineSpacing(4).textSelection(.enabled)
                    }
                    Text(AppInformation.licenseNotice).font(.system(size: 12)).lineSpacing(4)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        Link("Weather data by Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                        Text("·").foregroundStyle(.secondary)
                        Link("CC BY 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
                    }.font(.caption)
                }.padding(24)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack {
                Text("© 2026 · All rights reserved").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Done", action: close).keyboardShortcut(.cancelAction)
            }.padding(.horizontal, 24).padding(.vertical, 14)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
