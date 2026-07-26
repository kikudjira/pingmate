import SwiftUI

/// Single source for the values the design defines, mirroring the variables in `pingmate.pen`.
/// Anything that appeared as a magic number in more than one view lives here.
enum Tokens {
    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 14
    }

    /// 4pt grid.
    enum Space {
        static let x1: CGFloat = 4
        static let x2: CGFloat = 8
        static let x3: CGFloat = 12
        static let x4: CGFloat = 16
        static let x5: CGFloat = 20
        static let x6: CGFloat = 24
    }

    enum Size {
        /// Menubar glyph.
        static let trayIcon: CGFloat = 18
        /// Status dot in a history row.
        static let dotSmall: CGFloat = 10

        static let popoverWidth: CGFloat = 300
        static let monitorWindow = CGSize(width: 560, height: 640)
        static let monitorWindowMin = CGSize(width: 480, height: 420)
        static let settingsWindowWidth: CGFloat = 400
        /// Minimum equals the height the whole form needs, so the settings window cannot be
        /// shrunk into a scrolling state. The `ScrollView` behind it only earns its keep on a
        /// display too short for the form, or when inline errors push it over.
        /// Content height, not window height — a titlebar adds ~28pt on top. The form
        /// measures 567pt plus a 38pt pinned footer, so nothing scrolls at this size.
        /// Applied via `contentMinSize`, since `minSize` counts the titlebar too and let the
        /// footer be clipped.
        static let settingsWindowMin = CGSize(width: 400, height: 620)
    }

    enum Sparkline {
        /// Target bar thickness; the actual count of bars follows from the available width,
        /// so a wider surface shows more history rather than fatter bars.
        static let barWidth: CGFloat = 4
        static let barSpacing: CGFloat = 2
        static let cornerRadius: CGFloat = 1
        /// Milliseconds mapped to full bar height. Fixed rather than derived from the peak so
        /// the same latency always draws the same height across surfaces and over time.
        static let ceilingMilliseconds: Double = 300
        /// Timeouts draw at full height, dimmed — off the scale rather than a missing bar.
        static let timeoutOpacity: Double = 0.3
    }

    /// How long a recovery ring stays on the menubar icon.
    static let statusTransitionDuration: TimeInterval = 5
}

/// Off-switch for the glass effect. Off-screen renderers draw nothing for `glassEffect`, so
/// the preview harness turns it off and falls back to a material to check layout.
private struct GlassEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var glassEnabled: Bool {
        get { self[GlassEnabledKey.self] }
        set { self[GlassEnabledKey.self] = newValue }
    }
}

struct GlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    let interactive: Bool
    var tint: Color?

    @Environment(\.glassEnabled) private var glassEnabled

    func body(content: Content) -> some View {
        if glassEnabled {
            content.glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
        } else {
            content.background(.regularMaterial, in: .rect(cornerRadius: cornerRadius))
        }
    }

    private var glass: Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        return interactive ? glass.interactive() : glass
    }
}

extension View {
    /// Glass surface used for every card, tile and button in the app.
    func glassCard(cornerRadius: CGFloat = Tokens.Radius.medium, interactive: Bool = false) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, interactive: interactive))
    }

    /// Circular glass surface with a tint, for the icon-only monitoring toggle.
    func glassCircle(diameter: CGFloat, tint: Color) -> some View {
        modifier(GlassSurface(cornerRadius: diameter / 2, interactive: true, tint: tint))
    }
}
