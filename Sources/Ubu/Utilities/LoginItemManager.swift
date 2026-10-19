import Foundation
import ServiceManagement

final class LoginItemManager {
    private let service = SMAppService.mainApp

    var isEnabled: Bool {
        service.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
                Log.app.info("Login item registered")
            } else {
                try service.unregister()
                Log.app.info("Login item unregistered")
            }
        } catch {
            Log.app.error("Login item toggle failed: \(error.localizedDescription)")
        }
    }

    /// Opts in on first launch only. After that the menu toggle is the source of truth.
    func registerOnFirstLaunch(defaults: UserDefaults = .standard) {
        if Self.claimFirstLaunch(defaults) {
            setEnabled(true)
        }
    }

    /// True exactly once per defaults domain.
    static func claimFirstLaunch(_ defaults: UserDefaults) -> Bool {
        let key = "didRegisterLoginItem"
        guard !defaults.bool(forKey: key) else { return false }
        defaults.set(true, forKey: key)
        return true
    }
}
