import SwiftUI

extension VerticalAlignment {
    /// Centre line of the reading itself. Without it the row centres on the whole
    /// reading-plus-subtitle block and the circle sits low against the number.
    private struct ReadingCenter: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    static let readingCenter = VerticalAlignment(ReadingCenter.self)
}

/// Current state, in one row: status circle, the reading with its target underneath, and the
/// monitoring toggle. The circle centres on the reading's own line; the toggle spans and centres
/// on the whole reading-plus-target block.
struct StatusHeadline: View {
    let status: ConnectionStatus
    let pingTime: Double?
    let target: String
    let intervalMilliseconds: Int
    let isMonitoring: Bool
    let colors: Settings.IconColors
    /// Point size of the reading; every other size in the row follows it.
    let scale: CGFloat
    let onToggle: () -> Void

    /// Height of the circle-and-text row, which the toggle matches. Measured rather than derived
    /// from font metrics: the subtitle uses a text style whose size follows the user's settings.
    @State private var blockHeight: CGFloat = 0

    private var gap: CGFloat { scale > 30 ? Tokens.Space.x3 : Tokens.Space.x2 }

    var body: some View {
        HStack(spacing: gap) {
            readingBlock
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { blockHeight = $0 }

            MonitoringToggle(
                isMonitoring: isMonitoring,
                // Before the first layout pass, the point size is the closest stand-in.
                diameter: blockHeight > 0 ? blockHeight : scale,
                action: onToggle
            )
        }
    }

    /// Everything the toggle sizes itself against, so its height and centre follow the block
    /// rather than the reading alone.
    private var readingBlock: some View {
        HStack(alignment: .readingCenter, spacing: gap) {
            Circle()
                .fill(status.color(using: colors))
                .frame(width: circleDiameter, height: circleDiameter)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(reading)
                    .font(.system(size: scale, weight: .semibold, design: .rounded).monospacedDigit())
                    // Carries the row's alignment out of this stack, so the circle and the
                    // toggle track the number and not the number-plus-subtitle block.
                    .alignmentGuide(.readingCenter) { $0[VerticalAlignment.center] }
                    .lineLimit(1)
                    // No `minimumScaleFactor`: squeezing the window made the main reading
                    // shrink, which read as a rendering glitch rather than a layout response.
                    .fixedSize()
                    .foregroundStyle(pingTime == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(status.localizedName)
            .accessibilityValue("\(reading), \(subtitle)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Cap height of the reading, not its point size: a digit fills roughly 70% of the em, so a
    /// circle at the point size out-weighs the number it stands next to.
    private var circleDiameter: CGFloat {
        let base = NSFont.systemFont(ofSize: scale, weight: .semibold)
        let rounded = base.fontDescriptor.withDesign(.rounded).map { NSFont(descriptor: $0, size: scale) } ?? nil
        return ((rounded ?? base).capHeight).rounded()
    }

    private var reading: String {
        guard let pingTime else { return "—" }
        return String(format: "%.0f ms", pingTime)
    }

    private var subtitle: String {
        "\(target) · every \(Self.intervalText(intervalMilliseconds))"
    }

    /// Seconds, matching how the interval is entered in Settings.
    static func intervalText(_ milliseconds: Int) -> String {
        let seconds = Double(milliseconds) / 1000
        return seconds == seconds.rounded()
            ? String(format: "%.0fs", seconds)
            : String(format: "%.1fs", seconds)
    }
}

/// Neutral rather than accent-tinted: the blue read as a stray system control, and on the dark
/// glass surface it lost its edge entirely. `Color.primary` inverts with the appearance, so the
/// glyph is white on dark and black on light, and the stroked ring gives the boundary that glass
/// on glass never draws by itself.
struct MonitoringToggle: View {
    let isMonitoring: Bool
    let diameter: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isMonitoring ? "pause.fill" : "play.fill")
                .font(.system(size: diameter * 0.38, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: diameter, height: diameter)
                .contentShape(.circle)
                .glassCircle(diameter: diameter, tint: Color.primary.opacity(0.10))
                .overlay {
                    Circle().strokeBorder(Color.primary.opacity(0.22), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(isMonitoring ? "Pause monitoring" : "Resume monitoring")
        .accessibilityLabel(isMonitoring ? "Pause monitoring" : "Resume monitoring")
    }
}
