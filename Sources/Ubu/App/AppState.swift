import Foundation

/// What ubu should be doing right now. Everything that gates monitoring feeds in
/// here, and both the menu and the monitor follow the result.
enum AppState: Equatable {
    case needsPermission
    case needsSubscription
    case paused
    case active

    static func resolve(trusted: Bool, subscribed: Bool, paused: Bool) -> AppState {
        if !trusted { return .needsPermission }
        if !subscribed { return .needsSubscription }
        return paused ? .paused : .active
    }

    var isMonitoring: Bool { self == .active }
}

enum Links {
    static let privacyPolicy = URL(string: "https://github.com/fluxscale/ubu/blob/main/PRIVACY.md")!
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let manageSubscriptions = URL(string: "https://apps.apple.com/account/subscriptions")!
}
