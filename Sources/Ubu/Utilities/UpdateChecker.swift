import AppKit

final class UpdateChecker {
    private static let repo = "fluxscale/ubu"
    private static let releasesURL = "https://api.github.com/repos/\(repo)/releases/latest"

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    static func checkInBackground(silent: Bool = true) {
        DispatchQueue.global(qos: .utility).async {
            guard let (tag, url) = fetchLatestRelease() else { return }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            if compareVersions(latest, isNewerThan: currentVersion) {
                DispatchQueue.main.async {
                    showUpdateAlert(version: latest, downloadURL: url)
                }
            } else if !silent {
                DispatchQueue.main.async { showUpToDateAlert() }
            }
        }
    }

    private static func fetchLatestRelease() -> (tag: String, url: String)? {
        guard let url = URL(string: releasesURL) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let semaphore = DispatchSemaphore(value: 0)
        var result: (String, String)?

        URLSession.shared.dataTask(with: request) { data, _, error in
            defer { semaphore.signal() }
            guard error == nil, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String,
                  let htmlURL = json["html_url"] as? String else { return }
            result = (tag, htmlURL)
        }.resume()

        semaphore.wait()
        return result
    }

    static func compareVersions(_ remote: String, isNewerThan local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }

    private static func showUpdateAlert(version: String, downloadURL: String) {
        let alert = NSAlert()
        alert.messageText = "ubu v\(version) Available"
        alert.informativeText = "A new version of ubu is available. You are running v\(currentVersion)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: downloadURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private static func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = "You're Up to Date"
        alert.informativeText = "ubu v\(currentVersion) is the latest version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
