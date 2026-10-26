import BmuxWorkBrief
import Foundation

/// Converts existing live bmux and PE facts into a bounded briefing snapshot.
struct WorkBriefLocalAdapter {
    func snapshot(_ result: WorkspaceExplorerHistoryLoadResult,
                  surfaceIDs: [UUID: String] = [:],
                  associationPartial: Bool = false,
                  checkedAt: Date = Date()) -> WorkBriefSnapshot {
        let open = result.items.filter { $0.liveWorkspaceID != nil }.prefix(100)
        let items = open.compactMap { item -> WorkBriefLocalWorkspace? in
            guard let id = UUID(uuidString: item.id), let runtimeID = item.liveWorkspaceID else { return nil }
            let display = item.display
            let tickets = (display?.ticketLinks ?? []).prefix(12).compactMap { ticket -> WorkBriefLink? in
                guard let url = Self.webURL(ticket.url) else { return nil }
                let source: WorkBriefSource = ticket.system == "linear" ? .linear : .provenanceEngine
                return WorkBriefLink(id: ticket.id, label: ticket.id, url: url, source: source)
            }
            let pullRequest = Self.webURL(display?.pullRequestURL).map { url in
                WorkBriefLink(id: url.absoluteString,
                    label: display?.pullRequestNumber.map { "#\($0)" } ?? url.host ?? url.absoluteString,
                    url: url, source: .github)
            }
            var evidence = [WorkBriefEvidence(id: "\(id):presence", source: .bmux,
                field: "workspace", isObserved: true, checkedAt: checkedAt)]
            if let display {
                let observedAt = display.observedAt
                for (field, metadataKey, present) in [
                    ("repository", "repository_id", display.repositoryID != nil),
                    ("branch", "branch", display.branch != nil),
                    ("ticket", "ticket_links", !tickets.isEmpty),
                    ("pullRequest", "pull_request_url", pullRequest != nil)
                ] where present {
                    let metadata = display.fieldMetadata[metadataKey]
                    evidence.append(WorkBriefEvidence(id: "\(id):\(field)", source: .provenanceEngine,
                        field: field, isObserved: true, checkedAt: metadata?.observedAt ?? observedAt,
                        url: field == "pullRequest" ? pullRequest?.url :
                            field == "ticket" ? tickets.first?.url : nil,
                        referenceID: metadata?.evidenceEventID))
                }
            }
            if surfaceIDs[id] != nil {
                evidence.append(WorkBriefEvidence(id: "\(id):surface", source: .provenanceEngine,
                    field: "surface", isObserved: true, checkedAt: checkedAt))
            }
            return WorkBriefLocalWorkspace(id: id, runtimeID: runtimeID, title: item.title,
                repository: display?.repositoryID.map { result.repositoryNamesByID[$0] ?? $0 },
                branch: display?.branch, tickets: tickets, pullRequest: pullRequest,
                status: Self.status(item.liveStatus), surfaceID: surfaceIDs[id],
                lastActivityAt: item.lastActivityAt, checkedAt: checkedAt, evidence: evidence)
        }
        let partial = result.partialLiveActivity || result.liveMetadataPending || associationPartial ||
            result.items.count > 100
        let localHealth = WorkBriefSourceHealth(state: partial ? .partial : .available,
            checkedAt: checkedAt, reasonCode: partial ? "partial_live_facts" : nil)
        let unavailable = WorkBriefSourceHealth(state: .notConfigured, checkedAt: nil)
        return WorkBriefSnapshot(localWorkspaces: items, localHealth: localHealth,
            linearHealth: unavailable, githubHealth: unavailable, slackHealth: unavailable)
    }

    private static func webURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme == "https", url.host != nil else { return nil }
        return url
    }

    private static func status(_ status: WorkspaceExplorerStatus) -> WorkBriefLocalStatus {
        switch status {
        case .needsInput: .needsInput
        case .error: .error
        case .running: .running
        case .idle: .idle
        case .disconnected, .closedHistorical: .disconnected
        }
    }
}
