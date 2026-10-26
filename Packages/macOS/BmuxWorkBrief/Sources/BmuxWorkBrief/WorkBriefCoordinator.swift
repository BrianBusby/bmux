import Foundation
import Observation

/// Owns refresh state for the built-in Work Brief without navigating during refresh.
@MainActor @Observable
public final class WorkBriefCoordinator {
    /// Produces a bounded snapshot from current sources.
    public typealias Loader = @MainActor () async -> WorkBriefSnapshot

    /// Latest source facts.
    public private(set) var snapshot: WorkBriefSnapshot?
    /// Whether a refresh is in progress.
    public private(set) var isLoading = false
    private let load: Loader
    private var refreshAgain = false
    private var statusChangesDuringRefresh: [UUID: WorkBriefLocalStatus] = [:]

    /// Creates the coordinator with an injected source loader.
    /// - Parameters:
    ///   - initialSnapshot: Presence facts available before the first source refresh.
    ///   - load: An asynchronous source read supplied by the app composition root.
    public init(initialSnapshot: WorkBriefSnapshot? = nil, load: @escaping Loader) {
        snapshot = initialSnapshot
        self.load = load
    }

    /// Coalesces source notifications while one refresh is in progress.
    public func refresh() async {
        if isLoading {
            refreshAgain = true
            return
        }
        isLoading = true
        repeat {
            refreshAgain = false
            let loaded = await load()
            snapshot = applying(statusChangesDuringRefresh, to: loaded)
            statusChangesDuringRefresh.removeAll()
        } while refreshAgain
        isLoading = false
    }

    /// Updates an observed local status without issuing a provenance read.
    /// - Parameters:
    ///   - id: The stable workspace identity from the live monitor.
    ///   - status: The newly verified local status.
    public func observeLocalStatus(id: UUID, status: WorkBriefLocalStatus) {
        if isLoading { statusChangesDuringRefresh[id] = status }
        guard let snapshot else { return }
        self.snapshot = applying([id: status], to: snapshot)
    }

    private func applying(_ statuses: [UUID: WorkBriefLocalStatus],
                          to snapshot: WorkBriefSnapshot) -> WorkBriefSnapshot {
        guard !statuses.isEmpty else { return snapshot }
        let items = snapshot.localWorkspaces.map { item in
            guard let status = statuses[item.id], status != item.status else { return item }
            return WorkBriefLocalWorkspace(id: item.id, runtimeID: item.runtimeID,
                title: item.title, repository: item.repository, branch: item.branch,
                tickets: item.tickets, pullRequest: item.pullRequest, status: status,
                pullRequestStatus: item.pullRequestStatus,
                surfaceID: item.surfaceID, lastActivityAt: item.lastActivityAt,
                checkedAt: item.checkedAt, evidence: item.evidence)
        }
        return WorkBriefSnapshot(localWorkspaces: items, externalItems: snapshot.externalItems,
            localHealth: snapshot.localHealth,
            linearHealth: snapshot.linearHealth, githubHealth: snapshot.githubHealth,
            slackHealth: snapshot.slackHealth)
    }
}
