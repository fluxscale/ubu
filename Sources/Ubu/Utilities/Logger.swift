import os

enum Log {
    private static let subsystem = "com.ubu.app"

    static let app = os.Logger(subsystem: subsystem, category: "app")
    static let eventTap = os.Logger(subsystem: subsystem, category: "eventTap")
    static let coreDock = os.Logger(subsystem: subsystem, category: "coreDock")
    static let accessibility = os.Logger(subsystem: subsystem, category: "accessibility")
    static let display = os.Logger(subsystem: subsystem, category: "display")
    static let monitor = os.Logger(subsystem: subsystem, category: "monitor")
}
