import Foundation

struct PingResult: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let target: String
    let pingTime: Double?  // nil = timeout/failure
    let status: ConnectionStatus

    var formattedTime: String {
        guard let time = pingTime else { return "Timeout" }
        return String(format: "%.0f ms", time)
    }

    /// Numeric value for the history table's Ping column — no unit, so the column sorts and
    /// exports as a number. A missing reply shows an em dash instead.
    var formattedValue: String {
        guard let time = pingTime else { return "—" }
        return String(format: "%.0f", time)
    }

    /// A ping with no reply is reported as "Timeout" rather than "Problem": both share the
    /// `.problem` status, but only one of them measured anything.
    var statusText: String {
        isSuccess ? status.localizedName : "Timeout"
    }

    var formattedTimestamp: String {
        Self.timeFormatter.string(from: timestamp)
    }

    var isSuccess: Bool {
        pingTime != nil
    }

    /// Non-optional so the Ping column can be sorted. Timeouts sort as the worst value, which
    /// is where they belong when looking for the bad entries.
    var sortablePing: Double {
        pingTime ?? .greatestFiniteMagnitude
    }

    /// Shared: a new `DateFormatter` per row was allocated on every render of the history list.
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    static func == (lhs: PingResult, rhs: PingResult) -> Bool {
        lhs.id == rhs.id
    }
}
