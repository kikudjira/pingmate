import SwiftUI

/// Bar chart of the most recent ping results with its caption, oldest bar on the left.
///
/// The bar count is not a constant: bars are drawn at a fixed thickness and however many fit
/// the available width is how much history the surface shows. The popover fits ~44, the
/// history window ~85, and both keep identical bar weight.
struct Sparkline: View {
    /// Newest-first, as `PingService.history` stores it.
    let history: [PingResult]
    let colors: Settings.IconColors
    var barsHeight: CGFloat = 46

    @State private var visibleCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.x2) {
            GeometryReader { geometry in
                let slots = Self.barCount(for: geometry.size.width)
                let bars = Array(history.prefix(slots).reversed())

                HStack(alignment: .bottom, spacing: Tokens.Sparkline.barSpacing) {
                    // Keep bars pinned to the right so a partially filled chart grows
                    // leftwards instead of stretching a few bars across the whole width.
                    if bars.count < slots {
                        Spacer(minLength: 0)
                    }
                    ForEach(bars) { result in
                        RoundedRectangle(cornerRadius: Tokens.Sparkline.cornerRadius)
                            .fill(result.status.color(using: colors))
                            .opacity(result.isSuccess ? 1 : Tokens.Sparkline.timeoutOpacity)
                            .frame(width: Tokens.Sparkline.barWidth, height: barHeight(for: result))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .onChange(of: slots, initial: true) { _, newValue in
                    visibleCount = newValue
                }
            }
            .frame(height: barsHeight)

            caption
        }
        .accessibilityElement()
        .accessibilityLabel("Recent ping history")
        .accessibilityValue(accessibilitySummary)
    }

    private var caption: some View {
        HStack {
            Text("last \(min(history.count, visibleCount)) pings")
            Spacer()
            if let peak = history.prefix(visibleCount).compactMap(\.pingTime).max() {
                Text(String(format: "peak %.0f ms", peak))
            }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }

    private var accessibilitySummary: String {
        let visible = history.prefix(visibleCount)
        let timeouts = visible.filter { !$0.isSuccess }.count
        guard let peak = visible.compactMap(\.pingTime).max() else { return "No data" }
        return String(format: "%d pings, peak %.0f ms, %d timeouts", visible.count, peak, timeouts)
    }

    private func barHeight(for result: PingResult) -> CGFloat {
        guard let time = result.pingTime else { return barsHeight }
        let capped = min(time, Tokens.Sparkline.ceilingMilliseconds)
        // Square root, not linear: on a linear scale a single 300 ms spike flattens ordinary
        // 20 ms traffic into an unreadable line.
        let fraction = (capped / Tokens.Sparkline.ceilingMilliseconds).squareRoot()
        return max(4, barsHeight * fraction)
    }

    static func barCount(for width: CGFloat) -> Int {
        let unit = Tokens.Sparkline.barWidth + Tokens.Sparkline.barSpacing
        guard unit > 0, width > 0 else { return 0 }
        return max(1, Int((width + Tokens.Sparkline.barSpacing) / unit))
    }
}
