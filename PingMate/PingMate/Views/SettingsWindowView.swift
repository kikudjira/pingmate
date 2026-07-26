import SwiftUI

struct SettingsWindowView: View {
    @ObservedObject var storage: SettingsStorage
    @ObservedObject var pingService: PingService

    var body: some View {
        SettingsTabView(storage: storage, pingService: pingService)
            // Both halves are needed: `contentMinSize` alone gets overridden by the hosting
            // view, which reports the SwiftUI content's own minimum to the window.
            .frame(
                minWidth: Tokens.Size.settingsWindowMin.width,
                minHeight: Tokens.Size.settingsWindowMin.height
            )
    }
}

#Preview {
    SettingsWindowView(
        storage: SettingsStorage(),
        pingService: PingService()
    )
    .frame(width: 400, height: 620)
}
