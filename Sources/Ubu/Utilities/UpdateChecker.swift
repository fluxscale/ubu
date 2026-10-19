#if !APP_STORE // The App Store updates the App Store edition; self-updating is not allowed there.
import AppKit

@MainActor
enum UpdateChecker {
    private static let releasesURL = URL(string: "https://api.github.com/repos/fluxscale/ubu/releases/latest")!

    private struct Release: Decodable {
        let tagName: String
        let htmlUrl: URL
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    /// `silent` (launch check) only speaks up when an update exists. A manual check
    /// always answers, including when GitHub can't be reached.
    static func checkInBackground(silent: Bool = true) {
        Task {
            guard let release = await fetchLatestRelease() else {
                if !silent { showAlert("Couldn't Check for Updates", "GitHub could not be reached. Try again later.") }
                return
            }
            let latest = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
            if compareVersions(latest, isNewerThan: currentVersion) {
                showUpdateAlert(version: latest, downloadURL: release.htmlUrl)
            } else if !silent {
                showAlert("You're Up to Date", "ubu v\(currentVersion) is the latest version.")
            }
        }
    }

    private static func fetchLatestRelease() async -> Release? {
        var request = URLRequest(url: releasesURL, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(Release.self, from: data)
    }

    nonisolated static func compareVersions(_ remote: String, isNewerThan local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }

    private static func showUpdateAlert(version: String, downloadURL: URL) {
        let alert = NSAlert()
        alert.messageText = "ubu v\(version) Available"
        alert.informativeText = "A new version of ubu is available. You are running v\(currentVersion)."
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(downloadURL)
        }
    }

    private static func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
#endif
