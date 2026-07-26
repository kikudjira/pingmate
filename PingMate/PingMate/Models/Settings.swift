import Foundation

/// How long ping results are kept in history.
enum HistoryRetention: Int, Codable, CaseIterable, Identifiable {
    case oneHour = 3600
    case threeHours = 10800
    case twelveHours = 43200
    case oneDay = 86400

    var id: Int { rawValue }

    var localizedName: String {
        switch self {
        case .oneHour: return "1 hour"
        case .threeHours: return "3 hours"
        case .twelveHours: return "12 hours"
        case .oneDay: return "24 hours"
        }
    }

    var duration: TimeInterval { TimeInterval(rawValue) }
}

struct Settings: Codable, Equatable {
    var pingTarget: String = "8.8.8.8"
    var pingInterval: Int = 1000  // ms
    var goodPingThreshold: Int = 50  // ms
    var unstablePingThreshold: Int = 250  // ms
    var startAtLogin: Bool = false
    var historyRetention: HistoryRetention = .threeHours

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
        historyRetention = try container.decodeIfPresent(HistoryRetention.self, forKey: .historyRetention) ?? defaults.historyRetention
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
