import SwiftUI

/// Glass button with an icon and a label. Used for every secondary action.
struct GlassButton: View {
    let title: String
    let systemImage: String
    var muted: Bool = false
    var fills: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.x1) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(muted ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
            .lineLimit(1)
            .padding(.vertical, 9)
            .padding(.horizontal, Tokens.Space.x3)
            .frame(maxWidth: fills ? .infinity : nil)
            .contentShape(.rect)
            .glassCard(cornerRadius: Tokens.Radius.small, interactive: true)
        }
        .buttonStyle(.plain)
    }
}

/// Icon-only glass button for tertiary actions that have an obvious glyph.
struct GlassIconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .frame(width: 33, height: 33)
                .contentShape(.rect)
                .glassCard(cornerRadius: Tokens.Radius.small, interactive: true)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Status as a dot plus its name, so a row is readable without relying on colour alone.
struct StatusPill: View {
    let result: PingResult
    let colors: Settings.IconColors

    var body: some View {
        HStack(spacing: Tokens.Space.x1) {
            Circle()
                .fill(result.status.color(using: colors))
                .opacity(result.isSuccess ? 1 : 0.55)
                .frame(width: 7, height: 7)
            Text(result.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Segmented status filter for the history table.
struct StatusFilterChips: View {
    @Binding var selection: ConnectionStatus?
    let colors: Settings.IconColors

    var body: some View {
        HStack(spacing: 2) {
            chip(title: "All", status: nil)
            ForEach(ConnectionStatus.filterable, id: \.self) { status in
                chip(title: status == .problem ? "Problem / Timeout" : status.localizedName, status: status)
            }
        }
        .padding(2)
        .glassCard(cornerRadius: Tokens.Radius.small)
    }

    private func chip(title: String, status: ConnectionStatus?) -> some View {
        let isSelected = selection == status
        return Button {
            selection = status
        } label: {
            HStack(spacing: 5) {
                if let status {
                    Circle()
                        .fill(status.color(using: colors))
                        .frame(width: 7, height: 7)
                }
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            .padding(.vertical, 5)
            .padding(.horizontal, Tokens.Space.x2)
            .contentShape(.rect)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
