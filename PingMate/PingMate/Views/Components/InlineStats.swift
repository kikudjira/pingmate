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
    let timeouts: Int
    let pings: Int
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

/// Names the period the statistics cover: "Last 1 hour", or "Last 42 min of 1 h" while the
/// window is still filling after a launch, a wake or a clear.
///
/// Without it the numbers had no stated scope, and the list stopped growing for no visible
/// reason once the retention period was full.
struct PeriodCaption: View {
    let retention: HistoryRetention
    let covered: TimeInterval
    /// Clock range of the retained pings, for the History window.
    var range: ClosedRange<Date>?
    var onChange: (() -> Void)?

    var body: some View {
        HStack(spacing: Tokens.Space.x1) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.secondary)
            Text(Self.title(retention: retention, covered: covered))
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            if let detail {
                Text(detail)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: Tokens.Space.x2)
            if let onChange {
                Button("Change…", action: onChange)
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                    .help("Choose how long history is kept")
            }
        }
        .font(.caption)
        .lineLimit(1)
    }

    private var detail: String? {
        if !Self.isFull(retention: retention, covered: covered) {
            return "of \(retention.abbreviatedName)"
        }
        guard let range else { return nil }
        return "· \(range.lowerBound.formatted(date: .omitted, time: .shortened)) – \(range.upperBound.formatted(date: .omitted, time: .shortened))"
    }

    /// A minute of slack, so a full window does not flicker back to "59 min" between trims.
    static func isFull(retention: HistoryRetention, covered: TimeInterval) -> Bool {
        covered >= retention.duration - 60
    }

    static func title(retention: HistoryRetention, covered: TimeInterval) -> String {
        guard !isFull(retention: retention, covered: covered) else {
            return "Last \(retention.localizedName)"
        }
        let minutes = Int(covered / 60)
        switch minutes {
        case ..<1: return "Last minute"
        case ..<60: return "Last \(minutes) min"
        default:
            let rest = minutes % 60
            return rest == 0 ? "Last \(minutes / 60) h" : "Last \(minutes / 60) h \(rest) min"
        }
    }
}
