import SwiftUI
import AppKit

struct SettingsTabView: View {
    @ObservedObject var storage: SettingsStorage
    @ObservedObject var pingService: PingService

    @State private var editedSettings: Settings
    @State private var showResetConfirmation = false
    @State private var saveError: String?
    /// Bumped on reset. Fields keep their own draft text and ignore external changes while
    /// focused, so a reset performed with the cursor still in a field would not reach them;
    /// changing the identity rebuilds them from the restored settings.
    @State private var formGeneration = 0
    /// Populated on commit, not on keystroke, so typing "1500" no longer flashes an error
    /// after "1", "15" and "150".
    @State private var fieldErrors: [String: String] = [:]

    init(storage: SettingsStorage, pingService: PingService) {
        self.storage = storage
        self.pingService = pingService
        _editedSettings = State(initialValue: storage.settings)
    }

    private var isDefaults: Bool { editedSettings == Settings() }

    var body: some View {
        VStack(spacing: 0) {
            // Indicators left on: at a short window height the last section really is below
            // the fold, and hiding the scrollbar made it look like the form was cut off.
            ScrollView(.vertical) {
                // One container for all four cards: glass sampled per-card made the short
                // System card read lighter than the rest.
                GlassEffectContainer(spacing: Tokens.Space.x4) {
                    VStack(alignment: .leading, spacing: Tokens.Space.x4) {
                        networkSection
                        thresholdsSection
                        historySection
                        systemSection
                    }
                }
                .padding(Tokens.Space.x4)
                .id(formGeneration)
            }

            Divider()

            // Pinned: the reset row used to live inside the ScrollView and scrolled out of reach.
            HStack {
                Button("Reset to Defaults") { showResetConfirmation = true }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(isDefaults ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
                    .disabled(isDefaults)

                Spacer()

                Text("Changes save automatically")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Tokens.Space.x4)
            .padding(.vertical, Tokens.Space.x3)
        }
        .confirmationDialog(
            "Reset to Defaults?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                do {
                    try storage.reset()
                    saveError = nil
                } catch {
                    saveError = error.localizedDescription
                }
                editedSettings = storage.settings
                fieldErrors = [:]
                formGeneration += 1
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all settings to their default values.")
        }
    }

    // MARK: - Sections

    private var networkSection: some View {
        SettingsSection(title: "Network") {
            VStack(alignment: .leading, spacing: Tokens.Space.x2) {
                SettingRow(title: "Target") {
                    HostField(host: $editedSettings.pingTarget, onCommit: autoSave)
                        .frame(width: 190)
                }
                if let error = fieldErrors["pingTarget"] {
                    FieldError(message: error)
                } else {
                    Text("IP address, hostname, or localhost")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            VStack(alignment: .leading, spacing: Tokens.Space.x2) {
                SettingRow(title: "Interval") {
                    SecondsField(
                        milliseconds: $editedSettings.pingInterval,
                        range: 0.5...60,
                        onCommit: autoSave
                    )
                }
                if let error = fieldErrors["pingInterval"] {
                    FieldError(message: error)
                } else {
                    Text("0.5 – 60 s, in steps of 0.5")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var thresholdsSection: some View {
        SettingsSection(title: "Status Thresholds") {
            thresholdRow(
                title: "Good",
                color: $editedSettings.iconColors.good,
                value: $editedSettings.goodPingThreshold,
                range: 1...1000,
                errorKey: "goodPingThreshold"
            )
            thresholdRow(
                title: "Unstable",
                color: $editedSettings.iconColors.unstable,
                value: $editedSettings.unstablePingThreshold,
                range: 1...5000,
                errorKey: "unstablePingThreshold"
            )

            HStack(spacing: Tokens.Space.x3) {
                ColorSwatch(hex: $editedSettings.iconColors.problem, onChange: autoSave)
                Text("Problem")
                Spacer()
                Text("anything slower, or no reply")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func thresholdRow(
        title: String,
        color: Binding<String>,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        errorKey: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.x2) {
            HStack(spacing: Tokens.Space.x3) {
                ColorSwatch(hex: color, onChange: autoSave)
                Text(title)
                Spacer()
                NumberField(value: value, range: range, suffix: "ms", step: 5, onCommit: autoSave)
            }
            if let error = fieldErrors[errorKey] {
                FieldError(message: error)
            }
        }
    }

    private var historySection: some View {
        SettingsSection(title: "History") {
            SettingRow(title: "Keep history for") {
                Picker("", selection: $editedSettings.historyRetention) {
                    ForEach(HistoryRetention.allCases) { retention in
                        Text(retention.localizedName).tag(retention)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
                .onChange(of: editedSettings.historyRetention) { _, _ in autoSave() }
            }

            Text(retentionEstimate)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    /// Spells out what the retention window means at the current interval — the old fixed
    /// 10 000-entry cap silently meant anything from 1.4 h to 14 h depending on it.
    private var retentionEstimate: String {
        let entries = Int(editedSettings.historyRetention.duration / (Double(editedSettings.pingInterval) / 1000))
        return "≈ \(entries.formatted()) entries at the current \(StatusHeadline.intervalText(editedSettings.pingInterval)) interval"
    }

    private var systemSection: some View {
        SettingsSection(title: "System") {
            SettingRow(title: "Start at Login") {
                Toggle("", isOn: $editedSettings.startAtLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: editedSettings.startAtLogin) { _, _ in autoSave() }
                    // Storage re-reads the system every time this window opens; the form holds
                    // its own draft and would otherwise keep showing a value the system dropped.
                    .onChange(of: storage.settings.startAtLogin) { _, actual in
                        guard editedSettings.startAtLogin != actual else { return }
                        editedSettings.startAtLogin = actual
                    }
            }

            if let saveError {
                FieldError(message: saveError)
            }
        }
    }

    // MARK: - Saving

    private func autoSave() {
        fieldErrors = [:]
        for error in editedSettings.validate() {
            fieldErrors[error.field] = error.message
        }
        guard fieldErrors.isEmpty else { return }

        // A blur with nothing changed used to reach the ping service anyway, tearing the
        // monitoring loop down and back up just for tabbing through the form.
        guard editedSettings != storage.settings else {
            saveError = nil
            return
        }

        storage.settings = editedSettings

        // Single write path: SettingsStorage publishes, StatusBarController forwards to
        // PingService. Calling the service here too produced two stop/start cycles per edit.
        do {
            try storage.save()
            saveError = nil
        } catch {
            saveError = error.localizedDescription
            // Storage rolls back what it could not apply; mirror that back into the form.
            editedSettings = storage.settings
        }
    }
}

/// Single free-form target field. Accepts an IPv4 address, `localhost`, or a hostname — the
/// previous four-octet control made hostnames impossible to type at all.
struct HostField: View {
    @Binding var host: String
    var onCommit: () -> Void = {}

    @State private var text: String = ""
    @State private var debounce: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("8.8.8.8 or example.com", text: $text)
            .textFieldStyle(.roundedBorder)
            .font(.body.monospacedDigit())
            .focused($isFocused)
            .onSubmit { commit() }
            .onChange(of: text) { _, _ in scheduleCommit() }
            .onAppear { text = host }
            .onChange(of: host) { _, newValue in
                // Only follow external changes while the user is not typing.
                if !isFocused { text = newValue }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .onDisappear { debounce?.cancel() }
    }

    /// Saves once typing pauses, and only if the host already parses — so "8.8.4" on the way
    /// to "8.8.4.4" neither saves nor flashes an error.
    private func scheduleCommit() {
        debounce?.cancel()
        debounce = Task {
            try? await Task.sleep(for: FieldCommit.debounce)
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard !Task.isCancelled, IPValidator.isValid(trimmed) else { return }
            host = trimmed
            onCommit()
        }
    }

    /// Blur and Enter commit whatever is there, valid or not, so an invalid entry surfaces
    /// its error rather than being silently dropped.
    private func commit() {
        debounce?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        text = trimmed
        host = trimmed
        onCommit()
    }
}

#Preview {
    SettingsTabView(storage: SettingsStorage(), pingService: PingService())
        .frame(width: 400, height: 600)
}
