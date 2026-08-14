import Foundation

/// Produces ordered Linear issue identifiers to try for an observed ticket number.
struct LinearTicketIdentifierAliasMap: Equatable, Sendable {
    static let companyCam = LinearTicketIdentifierAliasMap(prefixAliases: [
        "STE": ["INP"],
    ])

    private let canonicalPrefixesByObservedPrefix: [String: [String]]

    init(prefixAliases: [String: [String]] = [:]) {
        self.canonicalPrefixesByObservedPrefix = prefixAliases.reduce(into: [:]) { result, entry in
            guard let observedPrefix = Self.normalizedPrefix(entry.key) else { return }
            var seen = Set<String>()
            let canonicalPrefixes = entry.value.compactMap { value -> String? in
                guard let prefix = Self.normalizedPrefix(value),
                      prefix != observedPrefix,
                      seen.insert(prefix).inserted else {
                    return nil
                }
                return prefix
            }
            guard !canonicalPrefixes.isEmpty else { return }
            result[observedPrefix] = canonicalPrefixes
        }
    }

    func lookupCandidates(for ticketID: String) -> [String] {
        let normalized = ticketID.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return [] }
        guard let ticketParts = Self.ticketParts(normalized) else { return [normalized] }

        var candidates = [normalized]
        for prefix in canonicalPrefixesByObservedPrefix[ticketParts.prefix] ?? [] {
            let candidate = "\(prefix)-\(ticketParts.number)"
            guard !candidates.contains(candidate) else { continue }
            candidates.append(candidate)
        }
        return candidates
    }

    private static func ticketParts(_ ticketID: String) -> (prefix: String, number: String)? {
        let components = ticketID.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard components.count == 2,
              let prefix = normalizedPrefix(String(components[0])),
              !components[1].isEmpty,
              components[1].allSatisfy(\.isNumber) else {
            return nil
        }
        return (prefix: prefix, number: String(components[1]))
    }

    private static func normalizedPrefix(_ value: String) -> String? {
        let prefix = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !prefix.isEmpty else { return nil }
        return prefix
    }
}
