import OSLog

struct Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.kikudjira.pingmate"

    static let ping = Logger(subsystem: subsystem, category: "Ping")
    static let tray = Logger(subsystem: subsystem, category: "Tray")
    static let settings = Logger(subsystem: subsystem, category: "Settings")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let app = Logger(subsystem: subsystem, category: "App")
}
