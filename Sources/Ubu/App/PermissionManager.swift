import AppKit
import ApplicationServices

final class PermissionManager {
    enum Status: Equatable {
        case granted
        case denied
        case unknown
    }

    static func checkAccessibility() -> Status {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        )
        return trusted ? .granted : .denied
    }

    static func requestAccessibility() {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        if !trusted {
            Log.app.info("Accessibility permission requested — opening System Settings")
            openAccessibilitySettings()
        }
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    static func startMonitoringPermission(interval: TimeInterval = 1.0, onChange: @escaping (Status) -> Void) -> Timer {
        var lastStatus: Status = .unknown
        return Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            let current = checkAccessibility()
            if current != lastStatus || lastStatus == .unknown {
                lastStatus = current
                onChange(current)
            }
        }
    }
}
