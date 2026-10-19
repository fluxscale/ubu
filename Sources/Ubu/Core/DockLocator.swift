import AppKit

/// Finds the display the Dock is on from its window-list entry. The Dock keeps a
/// window at the Dock window level spanning the display it occupies. Window bounds
/// need no permission, so this works without Accessibility and inside the App Sandbox.
enum DockLocator {
    @MainActor
    static func dockWindowBounds() -> CGRect? {
        guard let dockPID = NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]]
        else { return nil }

        let dockLevel = Int(CGWindowLevelForKey(.dockWindow))
        for window in windows
        where (window[kCGWindowOwnerPID as String] as? pid_t) == dockPID
            && (window[kCGWindowLayer as String] as? Int) == dockLevel {
            if let bounds = window[kCGWindowBounds as String] as! CFDictionary?,
               let rect = CGRect(dictionaryRepresentation: bounds) {
                return rect
            }
        }
        return nil
    }

    static func display(containing dockBounds: CGRect, in screens: [ScreenInfo]) -> CGDirectDisplayID? {
        let center = CGPoint(x: dockBounds.midX, y: dockBounds.midY)
        return screens.first { $0.frame.contains(center) }?.displayID
    }
}
