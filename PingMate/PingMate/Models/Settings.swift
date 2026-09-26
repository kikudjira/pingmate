import Foundation

/// How long ping results are kept in history — and so the period every statistic covers.
///
/// Raw values are seconds and are what gets persisted. A value that is not a case any more
/// (3 hours was dropped) decodes to the default in `Settings.init(from:)` instead of failing.
enum HistoryRetention: Int, Codable, CaseIterable, Identifiable {
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600
    case twoHours = 7200
    case fourHours = 14400
    case sixHours = 21600
    case eightHours = 28800
    case twelveHours = 43200
    case oneDay = 86400

    /// Ceiling on retained entries, whatever the period. It is what the list, the export and the
    /// per-tick bookkeeping scale with, so a preset that would exceed it at the current interval
    /// is not offered.
    static let maxEntries = 100_000

    var id: Int { rawValue }

    var duration: TimeInterval { TimeInterval(rawValue) }

    /// "15 minutes", "1 hour", "24 hours".
    var localizedName: String {
        let minutes = rawValue / 60
        if minutes < 60 { return "\(minutes) minutes" }
        let hours = minutes / 60
        return hours == 1 ? "1 hour" : "\(hours) hours"
    }

    /// "15 min", "1 h" — for the "Last 42 min of 1 h" label while the window is still filling.
    var abbreviatedName: String {
        let minutes = rawValue / 60
        return minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h"
    }

    /// How many pings the period holds at the given interval.
    func entries(atInterval milliseconds: Int) -> Int {
        Int(duration * 1000 / Double(max(milliseconds, 1)))
    }

    func fits(interval milliseconds: Int) -> Bool {
        entries(atInterval: milliseconds) <= Self.maxEntries
    }

    /// Shortest interval at which this period fits, rounded up to the 0.5 s step Settings uses.
    var minimumInterval: Int {
        let exact = duration * 1000 / Double(Self.maxEntries)
        return Int((exact / 500).rounded(.up)) * 500
    }

    /// This period, or the longest one that still fits when the interval got shorter.
    func clamped(toInterval milliseconds: Int) -> HistoryRetention {
        fits(interval: milliseconds)
            ? self
            : Self.allCases.last { $0.fits(interval: milliseconds) } ?? .fifteenMinutes
    }
}

struct Settings: Codable, Equatable {
    var pingTarget: String = "8.8.8.8"
    var pingInterval: Int = 1000  // ms
    var goodPingThreshold: Int = 50  // ms
    var unstablePingThreshold: Int = 250  // ms
    var startAtLogin: Bool = false
    var historyRetention: HistoryRetention = .oneHour

    struct IconColors: Codable, Equatable {
        var good: String = "#559C24"
        var unstable: String = "#EAA93B"
        var problem: String = "#AE3B36"
        var `default`: String = "#808080"

        func colorFor(_ status: ConnectionStatus) -> String {
            switch status {
            case .good: return good
            case .unstable: return unstable
            case .problem: return problem
            case .unknown: return `default`
            }
        }

        init() {}

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let defaults = IconColors()
            good = try container.decodeIfPresent(String.self, forKey: .good) ?? defaults.good
            unstable = try container.decodeIfPresent(String.self, forKey: .unstable) ?? defaults.unstable
            problem = try container.decodeIfPresent(String.self, forKey: .problem) ?? defaults.problem
            `default` = try container.decodeIfPresent(String.self, forKey: .default) ?? defaults.default
        }
    }

    var iconColors: IconColors = IconColors()

    init() {}

    /// Decodes leniently: any key missing from persisted JSON falls back to its default.
    /// The synthesized initializer would throw on a missing key, which `SettingsStorage`
    /// swallows with `try?` — silently wiping every setting whenever a field is added.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Settings()
        pingTarget = try container.decodeIfPresent(String.self, forKey: .pingTarget) ?? defaults.pingTarget
        pingInterval = try container.decodeIfPresent(Int.self, forKey: .pingInterval) ?? defaults.pingInterval
        goodPingThreshold = try container.decodeIfPresent(Int.self, forKey: .goodPingThreshold) ?? defaults.goodPingThreshold
        unstablePingThreshold = try container.decodeIfPresent(Int.self, forKey: .unstablePingThreshold) ?? defaults.unstablePingThreshold
        startAtLogin = try container.decodeIfPresent(Bool.self, forKey: .startAtLogin) ?? defaults.startAtLogin
        // Decoded as a plain number: a stored period that is no longer offered would make the
        // enum decode throw, and that would take every other setting down with it.
        let retentionSeconds = try container.decodeIfPresent(Int.self, forKey: .historyRetention)
        historyRetention = (retentionSeconds.flatMap(HistoryRetention.init(rawValue:)) ?? defaults.historyRetention)
            .clamped(toInterval: pingInterval)
        iconColors = try container.decodeIfPresent(IconColors.self, forKey: .iconColors) ?? defaults.iconColors
    }

    // MARK: - Validation

    struct ValidationError: Error {
        let field: String
        let message: String
    }

    func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        // Validate ping target
        if !IPValidator.isValid(pingTarget) {
            errors.append(ValidationError(
                field: "pingTarget",
                message: "Invalid host"
            ))
        }

        // Validate ping interval
        if pingInterval < 500 || pingInterval > 60000 {
            errors.append(ValidationError(
                field: "pingInterval",
                message: "Interval must be between 500 and 60000 ms"
            ))
        }

        // Validate good threshold
        if goodPingThreshold < 1 || goodPingThreshold > 1000 {
            errors.append(ValidationError(
                field: "goodPingThreshold",
                message: "Good threshold must be between 1 and 1000 ms"
            ))
        }

        // Validate unstable threshold
        if unstablePingThreshold < 1 || unstablePingThreshold > 5000 {
            errors.append(ValidationError(
                field: "unstablePingThreshold",
                message: "Unstable threshold must be between 1 and 5000 ms"
            ))
        }

        // Validate threshold relationship
        if unstablePingThreshold <= goodPingThreshold {
            errors.append(ValidationError(
                field: "unstablePingThreshold",
                message: "Unstable threshold must be greater than good threshold"
            ))
        }

        return errors
    }

    var isValid: Bool {
        validate().isEmpty
    }

    func message(for field: String) -> String? {
        validate().first { $0.field == field }?.message
    }
}
