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
        /// Threshold fields share one width, and every number field one unit column, so "s"
        /// and "ms" do not shift the fields against each other.
        static let numberField: CGFloat = 72
        static let unitColumn: CGFloat = 20
        /// The value column on the right of Settings: field, unit and stepper together, so
        /// the steppers and units of every number row line up.
        static let valueColumn: CGFloat = 126
        /// The interval only ever holds "0.5" to "60", so its field is sized to that and not
        /// to the threshold fields.
        static let intervalField: CGFloat = 44
        /// Minimum equals the height the whole form needs, so the settings window cannot be
        /// shrunk into a scrolling state. The `ScrollView` behind it only earns its keep on a
        /// display too short for the form, or when inline errors push it over.
        /// Content height, not window height — a titlebar adds ~28pt on top. The form
        /// is a grouped `Form` of ~590pt plus a ~50pt pinned footer (measured: 20pt under the
        /// last group at this height), so nothing scrolls and nothing is left empty. The
        /// window also opens at this height, whatever size the autosave remembers.
        /// Applied via `contentMinSize`, since `minSize` counts the titlebar too and let the
        /// footer be clipped.
        static let settingsWindowMin = CGSize(width: 400, height: 640)
        /// Upper bound for the History window's status filter, so a segmented control that
        /// ignores `fixedSize` still leaves room for Export.
        static let statusFilterMaxWidth: CGFloat = 340
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

    /// Three text sizes. There were five in the History window alone, and a stat read 15pt in
    /// the popover and 13pt in the window.
    enum TextSize {
        /// Numbers in the stat tiles.
        static let value: CGFloat = 15
        /// Anything clicked or read: buttons, chips, list rows and header, the period caption.
        static let body: CGFloat = 12
        /// Supporting captions: tile labels, sparkline, footers, hints, "Change…".
        static let caption: CGFloat = 10
    }

    /// Height of every control that sits in a row with another — buttons, the filter chips,
    /// the window's stat tiles — so a row lines up.
    static let controlHeight: CGFloat = 33
    /// The same for the system-styled windows: the height of an `.extraLarge` bordered
    /// button and segmented control on macOS 26 (measured 36pt).
    static let systemControlHeight: CGFloat = 36

    /// Fills of the system-styled windows, History and Settings. Every surface there takes one
    /// of these, so a card, a tile and a ring cannot drift into shades of their own.
    enum Fill {
        /// Behind a group of content: the History header card and list. System Settings puts a
        /// shade like this behind a group — darker than a white window, lighter than #1E1E1E.
        static let group = Color(nsColor: .quaternarySystemFill)
        /// Behind a control-sized element — the stat tiles, the monitoring toggle — so it
        /// reads as the same weight as the bordered buttons beside it, one step above `group`.
        static let control = Color(nsColor: .tertiarySystemFill)
        /// Outline for a control drawn on a surface of the same tone.
        static let stroke = Color.primary.opacity(0.22)
    }

    /// How long a recovery ring stays on the menubar icon.
    static let statusTransitionDuration: TimeInterval = 5
}

/// Off-switch for the glass effect. Off-screen renderers draw nothing for `glassEffect`, so
/// the preview harness turns it off and falls back to a material to check layout.
private struct GlassEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

/// What the shared surfaces and controls are drawn with.
///
/// The popover keeps Liquid Glass, as the system's own menubar popovers do. The History and
/// Settings windows follow System Settings instead: a grouped fill on the window background
/// and native controls, so they read like system windows in both appearances.
enum SurfaceStyle {
    case glass
    case system
}

private struct SurfaceStyleKey: EnvironmentKey {
    static let defaultValue = SurfaceStyle.glass
}

extension EnvironmentValues {
    var glassEnabled: Bool {
        get { self[GlassEnabledKey.self] }
        set { self[GlassEnabledKey.self] = newValue }
    }

    var surfaceStyle: SurfaceStyle {
        get { self[SurfaceStyleKey.self] }
        set { self[SurfaceStyleKey.self] = newValue }
    }
}

/// Which system fill a surface takes in the system-styled windows.
enum SurfaceRole {
    case group
    case control

    var fill: Color {
        switch self {
        case .group: Tokens.Fill.group
        case .control: Tokens.Fill.control
        }
    }
}

struct GlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    let interactive: Bool
    var tint: Color?
    var role: SurfaceRole = .group

    @Environment(\.glassEnabled) private var glassEnabled
    @Environment(\.surfaceStyle) private var surfaceStyle

    func body(content: Content) -> some View {
        if surfaceStyle == .system {
            content.background(role.fill, in: .rect(cornerRadius: cornerRadius))
        } else if glassEnabled {
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
    /// `role` only matters in the system-styled windows; the popover draws glass either way.
    func glassCard(
        cornerRadius: CGFloat = Tokens.Radius.medium,
        interactive: Bool = false,
        role: SurfaceRole = .group
    ) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, interactive: interactive, role: role))
    }

    /// Circular glass surface with a tint, for the icon-only monitoring toggle.
    func glassCircle(diameter: CGFloat, tint: Color) -> some View {
        modifier(GlassSurface(cornerRadius: diameter / 2, interactive: true, tint: tint, role: .control))
    }
}
