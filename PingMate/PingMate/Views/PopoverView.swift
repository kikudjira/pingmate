import SwiftUI

struct PopoverView: View {
    @ObservedObject var pingService: PingService
    @ObservedObject var settingsStorage: SettingsStorage
    let onOpenMonitor: () -> Void
    let onOpenSettings: () -> Void

    @State private var selectedTab: Tab = .monitor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Tab: String, CaseIterable {
        case monitor = "Monitor"
        case about = "About"

        var icon: String {
            switch self {
            case .monitor: return "waveform.path.ecg"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.horizontal, Tokens.Space.x3)
                .padding(.vertical, Tokens.Space.x2)

            Divider()

            tabContent
        }
        // Width is fixed, height follows the content: the old fixed 340 disagreed with the
        // popover's own contentSize and could not grow with larger text.
        .frame(width: Tokens.Size.popoverWidth)
    }

    private var tabBar: some View {
        HStack(spacing: Tokens.Space.x1) {
            ForEach(Tab.allCases, id: \.self) { tab in
                TabButton(
                    title: tab.rawValue,
                    systemImage: tab.icon,
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .monitor:
            MonitorTabView(
                pingService: pingService,
                settingsStorage: settingsStorage,
                onOpenHistory: onOpenMonitor,
                onOpenSettings: onOpenSettings
            )
        case .about:
            AboutTabView(settingsStorage: settingsStorage)
        }
    }
}

#Preview {
    PopoverView(
        pingService: PingService(),
        settingsStorage: SettingsStorage(),
        onOpenMonitor: {},
        onOpenSettings: {}
    )
}
