import AppKit
import SwiftUI

@MainActor
class SettingsWindowController: NSObject {
    private var window: NSWindow?
    private let settingsStorage: SettingsStorage
    private let pingService: PingService

    init(settingsStorage: SettingsStorage, pingService: PingService) {
        self.settingsStorage = settingsStorage
        self.pingService = pingService
        super.init()
    }

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsWindowView(
            storage: settingsStorage,
            pingService: pingService
        )

        // Fixed starting size instead of a one-shot `fittingSize` measurement: that height was
        // computed once at creation, so inline validation messages appearing later pushed the
        // bottom of the form out of the window.
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        let height = min(Tokens.Size.settingsWindowMin.height, screenHeight - 100)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Tokens.Size.settingsWindowWidth, height: height),
            // Same chrome as the history window — `.fullSizeContentView` here made the two
            // windows render their backgrounds differently side by side.
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.contentView = NSHostingView(rootView: contentView)
        // contentMinSize, not minSize: the latter measures the whole window, so the titlebar
        // ate ~28pt of the form and clipped the pinned footer at the minimum size.
        window.contentMinSize = Tokens.Size.settingsWindowMin
        window.titlebarAppearsTransparent = true
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        Log.ui.info("Settings window opened")
    }

    func closeWindow() {
        window?.close()
    }

    var isWindowVisible: Bool {
        window?.isVisible ?? false
    }
}
