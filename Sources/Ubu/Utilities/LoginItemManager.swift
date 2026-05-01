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
}
