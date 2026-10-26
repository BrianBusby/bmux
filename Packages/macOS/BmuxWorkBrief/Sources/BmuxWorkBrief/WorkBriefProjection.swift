import Foundation

/// Deterministic, bounded local sections derived only from source facts.
public struct WorkBriefProjection: Equatable, Sendable {
    /// All open workspaces, ordered by verified attention and recent activity.
    public let inProgress: [WorkBriefLocalWorkspace]
    /// Local errors and explicit input requests.
    public let needsAttention: [WorkBriefLocalWorkspace]
    /// Waiting relationships require an explicit source and are unavailable in the local slice.
    public let waitingOn: [WorkBriefLocalWorkspace]

    /// Projects a source snapshot without inventing external status or links.
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
    }
}
