import AppKit
import SwiftUI

@MainActor
class MonitorWindowController: NSObject {
    private var window: NSWindow?
    private let pingService: PingService
    private let settingsStorage: SettingsStorage

    init(pingService: PingService, settingsStorage: SettingsStorage) {
        self.pingService = pingService
        self.settingsStorage = settingsStorage
        super.init()
    }

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = MonitorWindowView(
            pingService: pingService,
            settingsStorage: settingsStorage
        )

        let window = NSWindow(
            contentRect: NSRect(
                x: 0, y: 0,
                width: Tokens.Size.monitorWindow.width,
                height: Tokens.Size.monitorWindow.height
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        // Named after what the window shows, not after the app.
        window.title = "History"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.setFrameAutosaveName("MonitorWindow")
        window.isReleasedWhenClosed = false
        window.contentMinSize = Tokens.Size.monitorWindowMin

        // Transparent titlebar with content underneath
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        Log.ui.info("Monitor window opened")
    }

    func closeWindow() {
        window?.close()
    }

    var isWindowVisible: Bool {
        window?.isVisible ?? false
    }
}
