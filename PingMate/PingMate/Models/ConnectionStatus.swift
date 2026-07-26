import SwiftUI

enum ConnectionStatus: String, Codable, CaseIterable {
    case good
    case unstable
    case problem
    case unknown

    var localizedName: String {
        switch self {
        case .good: return "Good"
        case .unstable: return "Unstable"
        case .problem: return "Problem"
        case .unknown: return "Unknown"
        }
    }

    /// The three states the user can actually filter history by. `.unknown` only exists
    /// before the first ping and never reaches a stored result.
    static var filterable: [ConnectionStatus] { [.good, .unstable, .problem] }

    func color(using colors: Settings.IconColors) -> Color {
        switch self {
        case .good: return Color(hex: colors.good)
        case .unstable: return Color(hex: colors.unstable)
        case .problem: return Color(hex: colors.problem)
        case .unknown: return Color(hex: colors.default)
        }
    }

    func nsColor(using colors: Settings.IconColors) -> NSColor {
        switch self {
        case .good: return NSColor(hex: colors.good)
        case .unstable: return NSColor(hex: colors.unstable)
        case .problem: return NSColor(hex: colors.problem)
        case .unknown: return NSColor(hex: colors.default)
        }
    }
}
