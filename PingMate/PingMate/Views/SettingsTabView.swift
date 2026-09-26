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
            // The system's grouped form — the layout System Settings uses — rather than glass
            // cards: native section groups, row separators and controls, in both appearances.
            Form {
                networkSection
                thresholdsSection
                historySection
                systemSection
            }
            .formStyle(.grouped)
            .id(formGeneration)

            Divider()

            // Pinned: the reset row used to live inside the ScrollView and scrolled out of reach.
            HStack {
                Button("Reset to Defaults") { showResetConfirmation = true }
                    .disabled(isDefaults)

                Spacer()

                Text("Changes save automatically")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Tokens.Space.x5)
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
        Section("Network") {
            LabeledContent {
                HostField(host: $editedSettings.pingTarget, onCommit: autoSave)
                    .frame(width: 170)
            } label: {
                Text("Target")
                // Short enough that the field stays on the label's line; localhost is a
                // hostname too.
                RowNote(error: fieldErrors["pingTarget"], hint: "IP address or hostname")
            }

            LabeledContent {
                SecondsField(
                    milliseconds: $editedSettings.pingInterval,
                    range: 0.5...60,
                    onCommit: autoSave
                )
            } label: {
                Text("Interval")
                RowNote(error: fieldErrors["pingInterval"], hint: "0.5 – 60 s, in steps of 0.5")
            }
        }
    }

    private var thresholdsSection: some View {
        Section("Status Thresholds") {
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

            LabeledContent {
                Text("slower or no reply")
                    .foregroundStyle(.secondary)
            } label: {
                swatchLabel("Problem", color: $editedSettings.iconColors.problem)
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
        LabeledContent {
            NumberField(value: value, range: range, suffix: "ms", step: 5, onCommit: autoSave)
        } label: {
            swatchLabel(title, color: color)
            if let error = fieldErrors[errorKey] {
                RowNote(error: error, hint: nil)
            }
        }
    }

    private func swatchLabel(_ title: String, color: Binding<String>) -> some View {
        HStack(spacing: Tokens.Space.x2) {
            ColorSwatch(hex: color, onChange: autoSave)
            Text(title)
        }
    }

    private var historySection: some View {
        Section {
            // The native pop-up. `currentValueLabel` keeps the closed button to the period's
            // name; each item carries its cost, or the interval it needs, after it.
            Picker(selection: $editedSettings.historyRetention) {
                ForEach(HistoryRetention.allCases) { retention in
                    let fits = retention.fits(interval: editedSettings.pingInterval)
                    (Text(retention.localizedName)
                        + Text(fits
                            ? "  \(retention.entries(atInterval: editedSettings.pingInterval).formatted()) pings"
                            : "  needs \(StatusHeadline.intervalText(retention.minimumInterval)) interval")
                        .foregroundStyle(.secondary))
                        .tag(retention)
                        .selectionDisabled(!fits)
                }
            } label: {
                Text("Keep history for")
            } currentValueLabel: {
                Text(editedSettings.historyRetention.localizedName)
            }
            .pickerStyle(.menu)
            .onChange(of: editedSettings.historyRetention) { _, _ in autoSave() }
        } header: {
            Text("History")
        } footer: {
            VStack(alignment: .leading, spacing: Tokens.Space.x1) {
                Label(retentionEstimate, systemImage: "memorychip")
                Label("Kept in memory only — cleared when PingMate quits", systemImage: "info.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// What the period costs at the current interval. Memory is the entry count times the
    /// in-memory size of one result; the target string is shared between entries, not copied.
    private var retentionEstimate: String {
        let entries = editedSettings.historyRetention.entries(atInterval: editedSettings.pingInterval)
        let bytes = Int64(entries * MemoryLayout<PingResult>.stride)
        let memory = bytes.formatted(.byteCount(style: .memory))
        return "≈ \(entries.formatted()) pings · about \(memory)"
    }

    private var systemSection: some View {
        Section("System") {
            Toggle("Start at Login", isOn: $editedSettings.startAtLogin)
                .toggleStyle(.switch)
                .onChange(of: editedSettings.startAtLogin) { _, _ in autoSave() }
                // Storage re-reads the system every time this window opens; the form holds
                // its own draft and would otherwise keep showing a value the system dropped.
                .onChange(of: storage.settings.startAtLogin) { _, actual in
                    guard editedSettings.startAtLogin != actual else { return }
                    editedSettings.startAtLogin = actual
                }

            if let saveError {
                FieldError(message: saveError)
            }
        }
    }

    // MARK: - Saving

    private func autoSave() {
        // A shorter interval can push the chosen period over the entry ceiling; step down to
        // the longest period that still fits rather than refuse the interval.
        editedSettings.historyRetention = editedSettings.historyRetention.clamped(toInterval: editedSettings.pingInterval)

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
        // Titled but label-hidden: inside a grouped form a field's title is drawn as a label
        // beside it. The example goes in the prompt instead.
        TextField("Target", text: $text, prompt: Text("8.8.8.8 or example.com"))
            .labelsHidden()
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

/// Second line of a form row's label: the validation error when there is one, the hint
/// otherwise. A grouped form renders a label's second text as the row's subtitle.
private struct RowNote: View {
    let error: String?
    let hint: String?

    var body: some View {
        if let error {
            Text(error).foregroundStyle(.red)
        } else if let hint {
            Text(hint)
        }
    }
}
