import Foundation

/// Deterministic, bounded local sections derived only from source facts.
public struct WorkBriefProjection: Equatable, Sendable {
    /// All open workspaces, ordered by verified attention and recent activity.
    public let inProgress: [WorkBriefLocalWorkspace]
    /// Local errors and explicit input requests.
    public let needsAttention: [WorkBriefLocalWorkspace]
    /// Waiting relationships require an explicit source and are unavailable in the local slice.
    public let waitingOn: [WorkBriefLocalWorkspace]
    /// External source items requiring the user's attention.
    public let externalNeedsAttention: [WorkBriefExternalItem]
    /// External source items without an exact local relationship.
    public let externalInProgress: [WorkBriefExternalItem]
    /// External source items explicitly awaiting another actor.
    public let externalWaitingOn: [WorkBriefExternalItem]
    /// Exact-link matches inferred from provider facts and accepted local links.
    public let relatedWorkspaceIDs: [String: [UUID]]
    /// Bmux-inferred joins between separate observed provider and PE links.
    public let relationshipEvidenceByExternalID: [String: [UUID: WorkBriefEvidence]]
    /// External open PRs whose exact local PE link has a terminal status.
    public let conflictingExternalIDs: Set<String>

    /// Projects a source snapshot without inventing external status or links.
    /// - Parameter snapshot: The bounded source facts to classify.
    public init(snapshot: WorkBriefSnapshot) {
        inProgress = snapshot.localWorkspaces.sorted {
            if $0.status.rawValue != $1.status.rawValue { return $0.status.rawValue < $1.status.rawValue }
            if $0.lastActivityAt != $1.lastActivityAt {
                return ($0.lastActivityAt ?? .distantPast) > ($1.lastActivityAt ?? .distantPast)
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        needsAttention = inProgress.filter { $0.status == .needsInput || $0.status == .error }
        waitingOn = []
        let external = snapshot.externalItems.sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id < $1.id
        }
        var relationships: [String: [UUID]] = [:]
        var relationshipEvidence: [String: [UUID: WorkBriefEvidence]] = [:]
        for item in external {
            var ids: [UUID] = []
            var evidenceByWorkspace: [UUID: WorkBriefEvidence] = [:]
            for workspace in snapshot.localWorkspaces {
                let matchedField: String
                let observedField: String
                switch item.source {
                case .linear:
                    guard workspace.tickets.contains(where: {
                        $0.source == .linear &&
                        ($0.id.caseInsensitiveCompare(item.reference) == .orderedSame || $0.url == item.url)
                    }) else { continue }
                    matchedField = "ticketLinkMatch"
                    observedField = "ticket"
                case .github:
                    guard workspace.pullRequest?.source == .github,
                          workspace.pullRequest?.url == item.url else { continue }
                    matchedField = "pullRequestURLMatch"
                    observedField = "pullRequest"
                default:
                    continue
                }
                ids.append(workspace.id)
                let localEvidence = workspace.evidence.first {
                    $0.field == observedField && $0.source == .provenanceEngine && $0.url == item.url
                }
                evidenceByWorkspace[workspace.id] = WorkBriefEvidence(
                    id: "\(item.id):\(workspace.id):relationship", source: .bmux,
                    field: matchedField, isObserved: false,
                    checkedAt: min(item.checkedAt, workspace.checkedAt), url: item.url,
                    referenceID: localEvidence?.referenceID)
            }
            relationships[item.id] = ids
            relationshipEvidence[item.id] = evidenceByWorkspace
        }
        relatedWorkspaceIDs = relationships
        relationshipEvidenceByExternalID = relationshipEvidence
        conflictingExternalIDs = Set(external.filter { item in
            guard item.source == .github else { return false }
            let ids = Set(relationships[item.id] ?? [])
            return snapshot.localWorkspaces.contains { workspace in
                guard ids.contains(workspace.id),
                      let status = workspace.pullRequestStatus?.lowercased() else { return false }
                return status.contains("merged") || status.contains("closed")
            }
        }.map(\.id))
        externalNeedsAttention = external.filter { $0.disposition == .needsAttention }
        externalInProgress = external.filter {
            $0.disposition == .inProgress && (relationships[$0.id]?.isEmpty ?? true)
        }
        externalWaitingOn = external.filter { $0.disposition == .waitingOn }
    }
}
