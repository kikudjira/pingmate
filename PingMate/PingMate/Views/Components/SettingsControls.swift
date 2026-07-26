import SwiftUI
import AppKit

/// Titled group of settings on a glass card.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.x2) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Tokens.Space.x3) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Space.x4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }
}

/// Label on the left, control pinned to the right edge of the card.
///
/// `LabeledContent` places its content right after the label instead of spanning the row, so
/// controls ended up floating mid-card and the switch looked glued to its own label.
struct SettingRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: Tokens.Space.x3) {
            Text(title)
            Spacer(minLength: Tokens.Space.x3)
            content
        }
        .frame(maxWidth: .infinity)
    }
}

/// Inline validation message under a field.
struct FieldError: View {
    let message: String

    var body: some View {
        HStack(spacing: Tokens.Space.x1) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
        }
        .font(.caption2)
        .foregroundStyle(Color.red)
        .accessibilityElement(children: .combine)
    }
}

/// How long typing has to pause before a field saves itself.
///
/// Committing only on blur meant a change was silently discarded until focus moved; committing
/// per keystroke pushed 1, 15 and 150 through validation while typing "1500" and restarted the
/// ping loop each time. A short idle delay does neither.
enum FieldCommit {
    static let debounce: Duration = .milliseconds(600)
}

/// Text field for a whole-number setting, with a stepper.
struct NumberField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let suffix: String
    var step: Int = 1
    var width: CGFloat = 72
    var onCommit: () -> Void = {}

    @State private var text: String = ""
    @State private var debounce: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Tokens.Space.x2) {
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)  // native focus ring, unlike the old custom background
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(width: width)
                .focused($isFocused)
                .onSubmit { commit() }
                .onChange(of: text) { _, _ in scheduleCommit() }

            Text(suffix)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize()  // never let a narrow window break "ms" across two lines

            Stepper("", value: Binding(get: { value }, set: { apply($0) }), in: range, step: step)
                .labelsHidden()
        }
        .onAppear { text = String(value) }
        .onChange(of: value) { _, newValue in
            if !isFocused { text = String(newValue) }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { commit() }
        }
        .onDisappear { debounce?.cancel() }
    }

    /// Saves once typing pauses, but only if the value is already inside the allowed range —
    /// half-typed input neither saves nor raises an error.
    private func scheduleCommit() {
        debounce?.cancel()
        debounce = Task {
            try? await Task.sleep(for: FieldCommit.debounce)
            guard !Task.isCancelled, let parsed = Int(text), range.contains(parsed) else { return }
            apply(parsed)
        }
    }

    private func commit() {
        debounce?.cancel()
        guard let parsed = Int(text.filter(\.isNumber)) else {
            text = String(value)
            return
        }
        apply(parsed)
    }

    private func apply(_ newValue: Int) {
        let clamped = min(max(newValue, range.lowerBound), range.upperBound)
        value = clamped
        text = String(clamped)
        onCommit()
    }
}

/// Interval field. Shown in seconds with one decimal because half-second polling is a normal
/// choice, while storage stays in whole milliseconds so no settings migration is needed.
struct SecondsField: View {
    @Binding var milliseconds: Int
    let range: ClosedRange<Double>
    var step: Double = 0.5
    var onCommit: () -> Void = {}

    @State private var text: String = ""
    @State private var debounce: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    private var seconds: Double { Double(milliseconds) / 1000 }

    var body: some View {
        HStack(spacing: Tokens.Space.x2) {
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(width: 62)
                .focused($isFocused)
                .onSubmit { commit() }
                .onChange(of: text) { _, _ in scheduleCommit() }

            Text("s")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize()

            Stepper("", value: Binding(get: { seconds }, set: { apply($0) }), in: range, step: step)
                .labelsHidden()
        }
        .onAppear { text = Self.format(seconds) }
        .onChange(of: milliseconds) { _, _ in
            if !isFocused { text = Self.format(seconds) }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { commit() }
        }
        .onDisappear { debounce?.cancel() }
    }

    private func scheduleCommit() {
        debounce?.cancel()
        debounce = Task {
            try? await Task.sleep(for: FieldCommit.debounce)
            let parsed = Double(text.replacingOccurrences(of: ",", with: "."))
            guard !Task.isCancelled, let parsed, range.contains(parsed) else { return }
            apply(parsed)
        }
    }

    private func commit() {
        debounce?.cancel()
        // Accept both separators — a comma is what a Russian keyboard layout produces.
        guard let parsed = Double(text.replacingOccurrences(of: ",", with: ".")) else {
            text = Self.format(seconds)
            return
        }
        apply(parsed)
    }

    private func apply(_ newValue: Double) {
        let clamped = min(max(newValue, range.lowerBound), range.upperBound)
        // Snap to the step so the stored millisecond value stays a round number.
        let snapped = (clamped / step).rounded() * step
        milliseconds = Int((snapped * 1000).rounded())
        text = Self.format(snapped)
        onCommit()
    }

    static func format(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}

/// Colour circle that opens the shared colour panel.
struct ColorSwatch: View {
    @Binding var hex: String
    var diameter: CGFloat = 18
    var onChange: () -> Void = {}

    @State private var isHovering = false

    var body: some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: diameter, height: diameter)
            .overlay {
                // Without a ring a colour close to the surface disappears, and nothing marks
                // the swatch as clickable.
                Circle().strokeBorder(.separator, lineWidth: 1)
            }
            .scaleEffect(isHovering ? 1.1 : 1)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .onHover { isHovering = $0 }
            .onTapGesture {
                ColorPanelController.shared.present(initial: hex) { newHex in
                    hex = newHex
                    onChange()
                }
            }
            .accessibilityLabel("Colour")
            .accessibilityValue(hex)
            .accessibilityAddTraits(.isButton)
    }
}

/// Single owner of the shared `NSColorPanel`.
///
/// A block-based `NotificationCenter` observer per tap could not be removed by
/// `removeObserver(self, name:)`, so observers accumulated and one drag in the panel wrote the
/// same colour into every swatch opened earlier. One target/action pair cannot accumulate:
/// assigning a new one replaces the old.
@MainActor
final class ColorPanelController: NSObject {
    static let shared = ColorPanelController()

    private var onChange: ((String) -> Void)?

    func present(initial: String, onChange: @escaping (String) -> Void) {
        self.onChange = onChange

        let panel = NSColorPanel.shared
        panel.isContinuous = true
        panel.showsAlpha = false
        panel.color = NSColor(Color(hex: initial))
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange(_:)))
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorDidChange(_ sender: NSColorPanel) {
        onChange?(Color(sender.color).hexString)
    }
}
