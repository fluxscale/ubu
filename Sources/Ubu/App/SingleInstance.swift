import AppKit

/// Keeps one copy of ubu running across both editions: two copies would run two event
/// taps and two correction loops against each other. The newest launch wins.
@MainActor
enum SingleInstance {
    /// GitHub edition and App Store edition.
    static let bundleIDs = ["com.ubu.app", "com.fluxscale.ubu"]
    private static let quitNotification = Notification.Name("com.fluxscale.ubu.quit")

    /// Asks every other running copy to quit. Returns the copies still running afterwards.
    static func takeOver(timeout: TimeInterval = 3) -> [NSRunningApplication] {
        let others = otherCopies()
        guard !others.isEmpty else { return [] }
        Log.app.info("Asking \(others.count) other ubu copies to quit")

        // Copies from this version on listen for this; it is the only way a sandboxed
        // copy can ask. terminate() covers older copies, but is refused inside the sandbox.
        DistributedNotificationCenter.default().postNotificationName(
            quitNotification, object: String(getpid()), userInfo: nil, deliverImmediately: true)
        others.forEach { $0.terminate() }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, others.contains(where: { !$0.isTerminated }) {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        return others.filter { !$0.isTerminated }
    }

    /// Quits this copy when a newer one launches.
    static func quitWhenReplaced(_ quit: @escaping @MainActor () -> Void) {
        let me = String(getpid())
        DistributedNotificationCenter.default().addObserver(
            forName: quitNotification, object: nil, queue: .main
        ) { note in
            let senderPID = note.object as? String
            guard isFromAnotherCopy(sender: senderPID, me: me) else { return }
            MainActor.assumeIsolated {
                // Anyone can post a distributed notification: only obey a running ubu.
                guard let pid = senderPID.flatMap(pid_t.init),
                      let sender = NSRunningApplication(processIdentifier: pid),
                      let id = sender.bundleIdentifier, bundleIDs.contains(id) else {
                    Log.app.error("Ignoring quit request from a process that isn't ubu")
                    return
                }
                Log.app.info("A newer ubu launched; quitting")
                quit()
            }
        }
    }

    nonisolated static func isFromAnotherCopy(sender: String?, me: String) -> Bool {
        sender != nil && sender != me
    }

    private static func otherCopies() -> [NSRunningApplication] {
        let me = getpid()
        return bundleIDs
            .flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0) }
            .filter { $0.processIdentifier != me }
    }

    /// Shown when an older copy wouldn't quit; this copy then exits.
    static func explain(_ survivors: [NSRunningApplication]) {
        let names = survivors.map { app in
            let version = app.bundleURL.flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String } ?? "?"
            return "ubu \(version) (\(app.bundleURL?.path ?? "unknown location"))"
        }
        let alert = NSAlert()
        alert.messageText = "ubu Is Already Running"
        alert.informativeText = "\(names.joined(separator: "\n"))\n\nQuit it from its menu bar icon, then open this copy again."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
