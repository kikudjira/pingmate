import Foundation

struct IPValidator {
    /// Accepts an IPv4 address, `localhost`, or an RFC 1123 hostname.
    static func isValid(_ string: String) -> Bool {
        let target = string.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, target.count <= 253 else { return false }
        return isValidIPv4(target) || isValidHostname(target)
    }

    static func isValidIPv4(_ string: String) -> Bool {
        let octets = string.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return false }

        for octet in octets {
            guard !octet.isEmpty, octet.count <= 3,
                  octet.allSatisfy(\.isNumber),
                  let value = Int(octet), value >= 0, value <= 255 else {
                return false
            }
        }
        return true
    }

    /// RFC 1123: labels of 1–63 chars from [A-Za-z0-9-], not starting or ending with a hyphen.
    /// A single label (`localhost`, `router`) is allowed — those resolve on a local network.
    static func isValidHostname(_ string: String) -> Bool {
        // A trailing dot is a valid FQDN form; strip it before splitting.
        let host = string.hasSuffix(".") ? String(string.dropLast()) : string
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.isEmpty else { return false }

        for label in labels {
            guard (1...63).contains(label.count),
                  label.first != "-", label.last != "-",
                  label.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) else {
                return false
            }
        }

        // Reject all-numeric hosts — those are malformed IPv4 attempts, not hostnames.
        return labels.contains { $0.contains { $0.isLetter } }
    }
}
