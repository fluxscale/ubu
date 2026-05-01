import CoreGraphics
import Foundation

final class CoreDockBridge {
    enum Result {
        case success
        case unavailable
        case failed
    }

    private let frameworkPath: String
    private var handle: UnsafeMutableRawPointer?
    private(set) var isAvailable = false

    private typealias CoreDockCopyPreferencesFunc = @convention(c) () -> CFDictionary?
    private typealias CoreDockSetOrientationFunc = @convention(c) (Int32) -> Void

    private var copyPreferences: CoreDockCopyPreferencesFunc?

    init(frameworkPath: String = "/System/Library/PrivateFrameworks/CoreDock.framework/CoreDock") {
        self.frameworkPath = frameworkPath
    }

    func load() {
        guard let h = dlopen(frameworkPath, RTLD_LAZY) else {
            Log.coreDock.info("CoreDock framework not found at \(self.frameworkPath)")
            isAvailable = false
            return
        }
        handle = h

        if let sym = dlsym(h, "CoreDockCopyPreferences") {
            copyPreferences = unsafeBitCast(sym, to: CoreDockCopyPreferencesFunc.self)
            isAvailable = true
            Log.coreDock.info("CoreDock bridge loaded successfully")
        } else {
            isAvailable = false
            Log.coreDock.info("CoreDock symbols not resolved — layer disabled")
        }
    }

    func moveDockToDisplay(displayID: CGDirectDisplayID) -> Result {
        guard isAvailable else { return .unavailable }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = [
            "write", "com.apple.dock",
            "last-messagetray-display",
            "-int", "\(displayID)"
        ]
        do {
            try task.run()
            task.waitUntilExit()

            let killTask = Process()
            killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killTask.arguments = ["Dock"]
            try killTask.run()
            killTask.waitUntilExit()

            Log.coreDock.info("Dock moved to display \(displayID) via CoreDock bridge")
            return .success
        } catch {
            Log.coreDock.error("Failed to move Dock: \(error.localizedDescription)")
            return .failed
        }
    }

    func getDockPreferences() -> [String: Any]? {
        guard isAvailable, let copyPreferences = copyPreferences else { return nil }
        guard let prefs = copyPreferences() else { return nil }
        return prefs as? [String: Any]
    }

    deinit {
        if let h = handle {
            dlclose(h)
        }
    }
}
