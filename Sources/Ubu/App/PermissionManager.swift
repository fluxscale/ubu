import AppKit
import ApplicationServices

@MainActor
enum PermissionManager {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt, which already offers to open System Settings.
    static func requestAccessibility() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// Calls `onGranted` once, as soon as Accessibility is granted.
    static func waitForAccessibility(onGranted: @escaping @MainActor @Sendable () -> Void) -> Timer {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            MainActor.assumeIsolated { onGranted() }
        }
    }
}
