import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MonitorWindowView: View {
    @ObservedObject var pingService: PingService
    /// Observed rather than snapshotted: the window is created once and reused, so a copied-in
    /// `IconColors` stayed frozen at whatever the colours were on first open.
    @ObservedObject var settingsStorage: SettingsStorage

    @State private var statusFilter: ConnectionStatus?
    @State private var selection = Set<PingResult.ID>()
    @State private var showClearConfirmation = false
    @State private var hostWindow: NSWindow?

    private var settings: Settings { settingsStorage.settings }

    /// Always newest first, which is the order the service already stores.
    private var rows: [PingResult] {
        guard let statusFilter else { return pingService.history }
        return pingService.history.filter { $0.status == statusFilter }
    }

    var body: some View {
        VStack(spacing: Tokens.Space.x3) {
            header
            statsRow
            toolbar
            table
            footer
        }
        .padding(Tokens.Space.x4)
        .frame(minWidth: Tokens.Size.monitorWindowMin.width, minHeight: Tokens.Size.monitorWindowMin.height)
        .background(WindowReader { hostWindow = $0 })
        .confirmationDialog(
            "Clear history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear \(pingService.history.count.formatted()) entries", role: .destructive) {
                pingService.clearHistory()
                selection.removeAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This also resets the average, timeout and ping counters.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.x3) {
            StatusHeadline(
                status: pingService.currentStatus,
                pingTime: pingService.lastPingTime,
                target: settings.pingTarget,
                intervalMilliseconds: settings.pingInterval,
                isMonitoring: pingService.isMonitoring,
                colors: settings.iconColors,
                scale: 26,
                onToggle: toggleMonitoring
            )

            if !pingService.history.isEmpty {
                Sparkline(history: pingService.history, colors: settings.iconColors, barsHeight: 44)
            }
        }
        .padding(Tokens.Space.x3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var statsRow: some View {
        HStack(spacing: Tokens.Space.x5) {
            InlineStats(
                average: pingService.formattedAverage,
                timeouts: pingService.totalFailures,
                pings: pingService.totalPings,
                density: .hugging
            )
            Spacer(minLength: Tokens.Space.x3)
            GlassButton(title: "Clear history", systemImage: "trash", muted: true) {
                showClearConfirmation = true
            }
            .disabled(pingService.history.isEmpty)
        }
    }

    private var toolbar: some View {
        HStack(spacing: Tokens.Space.x2) {
            StatusFilterChips(selection: $statusFilter, colors: settings.iconColors)
            Spacer(minLength: Tokens.Space.x3)
            GlassButton(title: exportTitle, systemImage: "square.and.arrow.down", action: exportToCSV)
                .disabled(rows.isEmpty)
        }
    }

    /// A `List` with a hand-built header rather than `Table`.
    ///
    /// `Table` brings sorting nobody asked for plus AppKit header chrome — column dividers,
    /// drag-to-reorder, a reserved scroller gutter — that SwiftUI gives no way to switch off.
    /// A list keeps what is actually wanted (selection, keyboard navigation, ⌘C) and lets the
    /// columns look like the design.
    private var table: some View {
        Group {
            if rows.isEmpty {
                VStack(spacing: 0) {
                    columnHeader
                    Divider()
                    emptyState
                }
            } else {
                List(selection: $selection) {
                    Section {
                        ForEach(rows) { result in
                            row(result)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.visible)
                                .tag(result.id)
                        }
                    } header: {
                        // Inside the list so it shares the rows' geometry, and with the list's
                        // own insets zeroed on both: List applies different padding to a
                        // section header than to a row, which is what knocked the columns out
                        // of line. Horizontal padding now lives inside the views themselves.
                        columnHeader
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                // Rows are prepended every tick; without a top anchor the visible content
                // creeps as the content size grows.
                .defaultScrollAnchor(.top, for: .sizeChanges)
                .onCopyCommand { copyItems() }
                .contextMenu(forSelectionType: PingResult.ID.self) { _ in
                    Button("Copy") { writeSelectionToPasteboard() }
                }
            }
        }
        .clipShape(.rect(cornerRadius: Tokens.Radius.medium))
        .glassCard()
    }

    private var columnHeader: some View {
        HStack(spacing: Tokens.Space.x3) {
            Text("Time").frame(width: Self.timeWidth, alignment: .leading)
            Text("Target").frame(maxWidth: .infinity, alignment: .leading)
            Text("Ping (ms)").frame(width: Self.pingWidth, alignment: .trailing)
            Text("Status").frame(width: Self.statusWidth, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.vertical, Tokens.Space.x2)
        .padding(.horizontal, Self.horizontalInset)
        .frame(maxWidth: .infinity)
    }

    /// Applied inside both the header and the rows, so nothing can add a different amount
    /// to one of them.
    private static let horizontalInset = Tokens.Space.x3

    private func row(_ result: PingResult) -> some View {
        HStack(spacing: Tokens.Space.x3) {
            Text(result.formattedTimestamp)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: Self.timeWidth, alignment: .leading)

            Text(result.target)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(result.formattedValue)
                .monospacedDigit()
                .foregroundStyle(result.isSuccess ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                .frame(width: Self.pingWidth, alignment: .trailing)

            StatusPill(result: result, colors: settings.iconColors)
                .frame(width: Self.statusWidth, alignment: .trailing)
        }
        .font(.callout)
        .padding(.vertical, 5)
        .padding(.horizontal, Self.horizontalInset)
        .accessibilityElement(children: .combine)
    }

    private static let timeWidth: CGFloat = 76
    private static let pingWidth: CGFloat = 72
    private static let statusWidth: CGFloat = 92

    private var emptyState: some View {
        VStack(spacing: Tokens.Space.x2) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text(pingService.history.isEmpty ? "No pings recorded yet" : "Nothing matches this filter")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            if pingService.history.isEmpty {
                Text(pingService.isMonitoring ? "Waiting for the first result." : "Monitoring is paused.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Text(selection.isEmpty ? "No rows selected" : "\(selection.count.formatted()) selected")
            Spacer()
            Text("⌘C copies selected rows")
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }

    private var exportTitle: String {
        statusFilter == nil
            ? "Export (\(rows.count.formatted()))"
            : "Export \(rows.count.formatted()) shown"
    }

    private func toggleMonitoring() {
        if pingService.isMonitoring {
            pingService.stop()
        } else {
            pingService.start()
        }
    }

    // MARK: - Copy

    private var selectedRows: [PingResult] {
        selection.isEmpty ? rows : rows.filter { selection.contains($0.id) }
    }

    private func copyItems() -> [NSItemProvider] {
        [NSItemProvider(object: tabSeparatedSelection() as NSString)]
    }

    private func writeSelectionToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(tabSeparatedSelection(), forType: .string)
    }

    private func tabSeparatedSelection() -> String {
        selectedRows
            .map { "\($0.formattedTimestamp)\t\($0.target)\t\($0.formattedValue)\t\($0.statusText)" }
            .joined(separator: "\n")
    }

    // MARK: - Export

    private func exportToCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.nameFieldStringValue = "pingmate-history-\(Self.fileStamp.string(from: Date())).csv"
        panel.isExtensionHidden = false

        // Exports what is on screen, so a filtered view exports the filtered rows.
        let exported = rows

        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            write(exported, to: url)
        }

        // Sheet-modal, not a free-floating panel: in an accessory app a detached save panel
        // can end up behind other applications' windows.
        if let hostWindow {
            panel.beginSheetModal(for: hostWindow, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    private func write(_ results: [PingResult], to url: URL) {
        let header = "Timestamp,Target,Ping (ms),Status"
        let lines = results.map { result in
            [
                result.timestamp.iso8601String,
                result.target,
                // Bare number: the old export wrote "45 ms" into a numeric column, which every
                // spreadsheet then had to be cleaned up by hand.
                result.pingTime.map { String(format: "%.0f", $0) } ?? "",
                result.statusText
            ]
            .map(Self.escapeCSVField)
            .joined(separator: ",")
        }
        let csv = ([header] + lines).joined(separator: "\n") + "\n"

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            Log.ui.info("Exported \(results.count) ping results to CSV")
        } catch {
            Log.ui.error("Failed to export CSV: \(error.localizedDescription)")
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Could not export history"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            if let hostWindow {
                alert.beginSheetModal(for: hostWindow)
            } else {
                alert.runModal()
            }
        }
    }

    private static func escapeCSVField(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static let fileStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter
    }()
}

/// Hands the enclosing `NSWindow` back to SwiftUI so sheets can be attached to it instead of
/// to whatever window happens to be key.
struct WindowReader: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onResolve(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

#Preview {
    MonitorWindowView(
        pingService: PingService(),
        settingsStorage: SettingsStorage()
    )
    .frame(width: 560, height: 640)
}
