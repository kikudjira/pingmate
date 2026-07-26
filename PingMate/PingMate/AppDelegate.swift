import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock (backup to Info.plist LSUIElement)
        NSApp.setActivationPolicy(.accessory)

        // Initialize status bar controller
        statusBarController = StatusBarController()

        Log.app.info("PingMate started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.pingService.stop()
        Log.app.info("PingMate terminated")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
