import SwiftUI

/// Glass button with an icon and a label. Used for every secondary action.
struct GlassButton: View {
    let title: String
    let systemImage: String
    var muted: Bool = false
    var fills: Bool = false
    /// Labels of the buttons this one sits in a column with. Each is laid out hidden behind
    /// its own, so the whole column takes the width of the longest label rather than each
    /// button hugging its own — without a width that breaks with another font or language.
    var sharesWidthWith: [(title: String, systemImage: String)] = []
    let action: () -> Void

    @Environment(\.surfaceStyle) private var surfaceStyle

    var body: some View {
        if surfaceStyle == .system {
            Button(action: action) {
                ZStack {
                    ForEach(sharesWidthWith.indices, id: \.self) { index in
                        Label(sharesWidthWith[index].title, systemImage: sharesWidthWith[index].systemImage)
                            .hidden()
                    }
                    Label(title, systemImage: systemImage)
                }
                .frame(maxWidth: fills ? .infinity : nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.extraLarge)
        } else {
            glassButton
        }
    }

    private var glassButton: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.x1) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: Tokens.TextSize.body, weight: .medium))
            }
            .foregroundStyle(muted ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
            .lineLimit(1)
            .padding(.horizontal, Tokens.Space.x3)
            .frame(height: Tokens.controlHeight)
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
                .frame(width: Tokens.controlHeight, height: Tokens.controlHeight)
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
                .font(.system(size: Tokens.TextSize.body))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Segmented status filter for the history table.
struct StatusFilterChips: View {
    @Binding var selection: ConnectionStatus?
    let colors: Settings.IconColors

    @Environment(\.surfaceStyle) private var surfaceStyle

    var body: some View {
        if surfaceStyle == .system {
            // The native segmented control. Its segments draw images as templates, so the
            // status dots do not carry over; the status column in the list still shows them.
            Picker("Status", selection: $selection) {
                Text("All").tag(ConnectionStatus?.none)
                // Plain status names: segments share the widest label's width, and
                // "Problem / Timeout" made all four too wide for the row. The list's Status
                // column still tells a timeout from a slow reply.
                ForEach(ConnectionStatus.filterable, id: \.self) { status in
                    Text(status.localizedName)
                        .tag(ConnectionStatus?.some(status))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.extraLarge)
            // A segmented control takes all the width it is offered; pinned to its content it
            // leaves room for Export instead of pushing it out of the window.
            .fixedSize()
            .frame(maxWidth: Tokens.Size.statusFilterMaxWidth, alignment: .leading)
        } else {
            chips
        }
    }

    private var chips: some View {
        HStack(spacing: 2) {
            chip(title: "All", status: nil)
            ForEach(ConnectionStatus.filterable, id: \.self) { status in
                chip(title: status == .problem ? "Problem / Timeout" : status.localizedName, status: status)
            }
        }
        .padding(2)
        .frame(height: Tokens.controlHeight)
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
                    .font(.system(size: Tokens.TextSize.body, weight: isSelected ? .medium : .regular))
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            .padding(.horizontal, Tokens.Space.x2)
            .frame(maxHeight: .infinity)
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
