import Foundation
import ProvenanceEngineContracts

/// Extracts normalized workspace resource evidence from bounded text sources.
struct WorkProvenanceWorkspaceResourceDiscovery: Equatable, Sendable {
    enum TextSource: String, Hashable, Sendable {
        case pullRequestBranch
        case pullRequestTitle
        case storedSubmittedPrompt
        case submittedPrompt
    }

    struct TextEvidence: Equatable, Sendable {
        let source: TextSource
        let text: String

        init(source: TextSource, text: String) {
            self.source = source
            self.text = text
        }
    }

    struct TicketEvidence: Equatable, Sendable {
        let id: String
        let system: String
        let url: String?
        let sources: [TextSource]

        init(
            id: String,
            system: String,
            url: String?,
            sources: [TextSource]
        ) {
            self.id = id
            self.system = system
            self.url = url
            self.sources = sources
        }

        func merged(with incoming: TicketEvidence) -> TicketEvidence {
            TicketEvidence(
                id: id,
                system: system,
                url: url ?? incoming.url,
                sources: Self.mergedSources(sources, incoming.sources)
            )
        }

        private static func mergedSources(
            _ existingSources: [TextSource],
            _ incomingSources: [TextSource]
        ) -> [TextSource] {
            var seen = Set(existingSources)
            var merged = existingSources
            for source in incomingSources where seen.insert(source).inserted {
                merged.append(source)
            }
            return merged
        }
    }

    struct Result: Equatable, Sendable {
        let tickets: [TicketEvidence]

        init(tickets: [TicketEvidence] = []) {
            var order: [String] = []
            var byID: [String: TicketEvidence] = [:]
            for ticket in tickets {
                if let existing = byID[ticket.id] {
                    byID[ticket.id] = existing.merged(with: ticket)
                } else {
                    order.append(ticket.id)
                    byID[ticket.id] = ticket
                }
            }
            self.tickets = order.compactMap { byID[$0] }
        }

        var ticketIDs: [String] {
            tickets.map(\.id)
        }

        var explicitTicketLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord] {
            tickets.compactMap { ticket in
                guard let url = ticket.url else { return nil }
                return ProvenanceWorkspaceDisplayTicketLinkRecord(
                    id: ticket.id,
                    system: ticket.system,
                    title: nil,
                    url: url,
                    ownerName: nil,
                    ownerURL: nil
                )
            }
        }
    }

    private let linearExtractor: LinearTicketExtractor

    init(linearExtractor: LinearTicketExtractor = LinearTicketExtractor()) {
        self.linearExtractor = linearExtractor
    }

    func discover(in evidence: [TextEvidence]) -> Result {
        Result(tickets: evidence.flatMap { textEvidence in
            linearExtractor.ticketEvidence(in: textEvidence.text, source: textEvidence.source)
        })
    }
}

extension WorkProvenanceWorkspaceResourceDiscovery {
    struct LinearTicketExtractor: Equatable, Sendable {
        private static let linearIssueURLPattern = #"https://linear\.app/"#
            + #"([a-z0-9](?:[a-z0-9-]*[a-z0-9])?)/issue/"#
            + #"([A-Z]{2,}[A-Z0-9]*-[0-9]+)"#
            + #"(?:/[^\s"'<>\)]*)?"#
        private static let bareIssuePattern = #"(^|[^A-Z0-9])([A-Z]{2,}[A-Z0-9]*-[0-9]+)(?=$|[^A-Z0-9])"#
        private static let trailingURLPunctuation = CharacterSet(charactersIn: ".,;:")

        private let bareIssuePrefixes: Set<String>

        init(bareIssuePrefixes: Set<String> = ["INP", "STE"]) {
            self.bareIssuePrefixes = Set(bareIssuePrefixes.map { $0.uppercased() })
        }

        func ticketEvidence(
            in text: String,
            source: WorkProvenanceWorkspaceResourceDiscovery.TextSource
        ) -> [WorkProvenanceWorkspaceResourceDiscovery.TicketEvidence] {
            var tickets: [WorkProvenanceWorkspaceResourceDiscovery.TicketEvidence] = []
            tickets.append(contentsOf: urlTicketEvidence(in: text, source: source))
            tickets.append(contentsOf: bareTicketEvidence(in: text, source: source))
            return WorkProvenanceWorkspaceResourceDiscovery.Result(tickets: tickets).tickets
        }

        private func urlTicketEvidence(
            in text: String,
            source: WorkProvenanceWorkspaceResourceDiscovery.TextSource
        ) -> [WorkProvenanceWorkspaceResourceDiscovery.TicketEvidence] {
            guard let regex = try? NSRegularExpression(
                pattern: Self.linearIssueURLPattern,
                options: [.caseInsensitive]
            ) else {
                return []
            }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return regex.matches(in: text, range: range).compactMap { match in
                guard let idRange = Range(match.range(at: 2), in: text),
                      let urlRange = Range(match.range, in: text),
                      let ticketID = Self.normalizedTicketID(String(text[idRange])) else {
                    return nil
                }
                let url = String(text[urlRange])
                    .trimmingCharacters(in: Self.trailingURLPunctuation)
                return WorkProvenanceWorkspaceResourceDiscovery.TicketEvidence(
                    id: ticketID,
                    system: "linear",
                    url: url,
                    sources: [source]
                )
            }
        }

        private func bareTicketEvidence(
            in text: String,
            source: WorkProvenanceWorkspaceResourceDiscovery.TextSource
        ) -> [WorkProvenanceWorkspaceResourceDiscovery.TicketEvidence] {
            guard let regex = try? NSRegularExpression(
                pattern: Self.bareIssuePattern,
                options: [.caseInsensitive]
            ) else {
                return []
            }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return regex.matches(in: text, range: range).compactMap { match in
                guard let range = Range(match.range(at: 2), in: text),
                      let ticketID = normalizedBareTicketID(String(text[range])) else {
                    return nil
                }
                return WorkProvenanceWorkspaceResourceDiscovery.TicketEvidence(
                    id: ticketID,
                    system: "linear",
                    url: nil,
                    sources: [source]
                )
            }
        }

        private func normalizedBareTicketID(_ value: String) -> String? {
            guard let ticketID = Self.normalizedTicketID(value) else { return nil }
            let prefix = ticketID.split(separator: "-", maxSplits: 1).first.map(String.init) ?? ""
            guard bareIssuePrefixes.contains(prefix) else { return nil }
            return ticketID
        }

        private static func normalizedTicketID(_ value: String) -> String? {
            let ticketID = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard ticketID.range(
                of: #"^[A-Z]{2,}[A-Z0-9]*-[0-9]+$"#,
                options: .regularExpression
            ) != nil else {
                return nil
            }
            return ticketID
        }

    }
}
