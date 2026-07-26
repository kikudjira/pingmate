import SwiftUI

@main
struct PingMateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene - app lives only in the menu bar
        SwiftUI.Settings {
            EmptyView()
        }
    }
}
