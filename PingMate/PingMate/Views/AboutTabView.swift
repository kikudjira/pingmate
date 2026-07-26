import SwiftUI
import AppKit

struct AboutTabView: View {
    @ObservedObject var settingsStorage: SettingsStorage

    private var colors: Settings.IconColors { settingsStorage.settings.iconColors }

    var body: some View {
        VStack(spacing: Tokens.Space.x4) {
            identity
            legend
            footer
        }
        .padding(Tokens.Space.x5)
    }

    private var identity: some View {
        VStack(spacing: Tokens.Space.x2) {
            // The real app icon, not a stand-in symbol.
            if let icon = NSApplication.shared.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
            }

            Text("PingMate")
                .font(.system(size: 17, weight: .semibold))

            Text("Version \(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Spots problems with your internet connection the moment they start.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.x3) {
            // Colours come from settings, so a customised palette stays in sync with the legend.
            legendRow(.good, title: "Good", description: "Response under the good threshold")
            legendRow(.unstable, title: "Unstable", description: "Slower than usual, still reachable")
            legendRow(.problem, title: "Problem", description: "Too slow, or no reply at all")
        }
        .padding(Tokens.Space.x4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func legendRow(_ status: ConnectionStatus, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.x3) {
            Circle()
                .fill(status.color(using: colors))
                .frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: 2) {
            Text("© 2026 Andrey Sekirkin")
            Link("github.com/kikudjira", destination: URL(string: "https://github.com/kikudjira")!)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
}

#Preview {
    AboutTabView(settingsStorage: SettingsStorage())
        .frame(width: 300)
}
