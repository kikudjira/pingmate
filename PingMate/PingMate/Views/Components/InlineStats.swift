import SwiftUI

/// Average / timeouts / pings as a thin strip of glass tiles under the trend.
///
/// Deliberately lighter than a card grid: these numbers are supporting detail, and the chart
/// above them stays the dominant region.
struct InlineStats: View {
    enum Density {
        /// Tiles share the full width — for the narrow popover.
        case filling
        /// Tiles hug their content — for the wide window, where a stretched tile reads empty.
        case hugging
    }

    let average: String
    let timeouts: UInt64
    let pings: UInt64
    var density: Density = .filling

    var body: some View {
        GlassEffectContainer(spacing: Tokens.Space.x2) {
            HStack(spacing: Tokens.Space.x2) {
                tile(value: average, label: "avg")
                tile(value: timeouts.formatted(), label: "timeouts")
                tile(value: pings == 0 ? "—" : pings.formatted(), label: "pings")
            }
        }
    }

    private func tile(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: density == .filling ? 15 : 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .lineLimit(1)
        .padding(.vertical, density == .filling ? Tokens.Space.x2 : 7)
        .padding(.horizontal, density == .filling ? Tokens.Space.x2 : Tokens.Space.x4)
        .frame(maxWidth: density == .filling ? .infinity : nil)
        .glassCard(cornerRadius: Tokens.Radius.small)
        .accessibilityElement(children: .combine)
    }
}
