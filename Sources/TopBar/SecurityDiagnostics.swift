import Foundation
import Security

/// Explicit, non-interactive CI smoke test. Never runs during ordinary launches.
enum SecurityDiagnostics {
    static func run(arguments: [String]) -> Int32 {
        var code: SecCode?
        var info: CFDictionary?
        let hasCode = SecCodeCopySelf([], &code) == errSecSuccess
        var staticCode: SecStaticCode?
        if let code { _ = SecCodeCopyStaticCode(code, [], &staticCode) }
        if let staticCode { _ = SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) }
        let entitlements = (info as? [String: Any])?[kSecCodeInfoEntitlementsDict as String] as? [String: Any]
        var results = ["sandbox": hasCode && entitlements?["com.apple.security.app-sandbox"] as? Bool == true,
                       "cpu": SystemMetrics.cpu() != nil, "memory": SystemMetrics.memory() != nil]
        if arguments.contains("--require-network") { results["network"] = SystemMetrics.network() != nil }
        if let index = arguments.firstIndex(of: "--deny-read"), arguments.indices.contains(index + 1) {
            do {
                _ = try Data(contentsOf: URL(fileURLWithPath: arguments[index + 1]))
                results["outsideFileDenied"] = false
            } catch { results["outsideFileDenied"] = true }
        }
        if let data = try? JSONSerialization.data(withJSONObject: results, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) { print(text) }
        return results.values.allSatisfy { $0 } ? 0 : 1
    }
}
