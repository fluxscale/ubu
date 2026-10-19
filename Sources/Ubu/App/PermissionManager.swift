import AppKit
import ApplicationServices

@MainActor
enum PermissionManager {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt, which already offers to open System Settings.
    /// macOS shows it once per app; later calls only add ubu to the Accessibility list.
    static func requestAccessibility() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// For an explicit click: the system prompt won't reappear, so go straight to the pane.
    static func openAccessibilitySettings() {
        requestAccessibility()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
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
