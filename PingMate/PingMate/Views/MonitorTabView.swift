import SwiftUI

struct MonitorTabView: View {
    @ObservedObject var pingService: PingService
    @ObservedObject var settingsStorage: SettingsStorage
    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void

    @State private var showClearConfirmation = false

    private var settings: Settings { settingsStorage.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.x4) {
            StatusHeadline(
                status: pingService.currentStatus,
                pingTime: pingService.lastPingTime,
                target: settings.pingTarget,
                intervalMilliseconds: settings.pingInterval,
                isMonitoring: pingService.isMonitoring,
                colors: settings.iconColors,
                scale: 40,
                onToggle: toggleMonitoring
            )

            if pingService.history.isEmpty {
                emptyState
            } else {
                Sparkline(history: pingService.history, colors: settings.iconColors)
            }

            InlineStats(
                average: pingService.formattedAverage,
                timeouts: pingService.totalFailures,
                pings: pingService.totalPings
            )

            actions
        }
        .padding(Tokens.Space.x4)
        .confirmationDialog(
            "Clear history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear \(pingService.history.count.formatted()) entries", role: .destructive) {
                pingService.clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This also resets the average, timeout and ping counters.")
        }
    }

    /// First launch shows the chart's frame rather than a blank gap, so the popover does not
    /// jump in height the moment the first result lands.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.x2) {
            RoundedRectangle(cornerRadius: Tokens.Radius.small)
                .fill(.quaternary)
                .frame(height: 46)
                .overlay {
                    Text(pingService.isMonitoring ? "Waiting for the first ping…" : "Monitoring is paused")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            Text("No history yet")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var actions: some View {
        GlassEffectContainer(spacing: Tokens.Space.x2) {
            HStack(spacing: Tokens.Space.x2) {
                GlassButton(
                    title: "History",
                    systemImage: "list.bullet.rectangle",
                    fills: true,
                    action: onOpenHistory
                )

                // "Clear history" truncates at the popover's 300pt; the confirmation dialog
                // spells out what is cleared, so the shorter label loses nothing.
                GlassButton(title: "Clear", systemImage: "trash", muted: true) {
                    showClearConfirmation = true
                }
                .disabled(pingService.history.isEmpty)

                GlassIconButton(systemImage: "gearshape", help: "Settings", action: onOpenSettings)
            }
        }
    }

    private func toggleMonitoring() {
        if pingService.isMonitoring {
            pingService.stop()
        } else {
            pingService.start()
        }
    }
}

#Preview {
    MonitorTabView(
        pingService: PingService(),
        settingsStorage: SettingsStorage(),
        onOpenHistory: {},
        onOpenSettings: {}
    )
    .frame(width: 300)
}
