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
    /// Exact local relationships established through accepted source links.
    public let relatedWorkspaceIDs: [String: [UUID]]
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
        for item in external {
            relationships[item.id] = snapshot.localWorkspaces.filter { workspace in
                switch item.source {
                case .linear:
                    workspace.tickets.contains {
                        $0.source == .linear &&
                        ($0.id.caseInsensitiveCompare(item.reference) == .orderedSame || $0.url == item.url)
                    }
                case .github:
                    workspace.pullRequest?.source == .github && workspace.pullRequest?.url == item.url
                default:
                    false
                }
            }.map(\.id)
        }
        relatedWorkspaceIDs = relationships
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
