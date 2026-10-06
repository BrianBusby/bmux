import Foundation

/// Value snapshots of repository names for a workspace list.
@MainActor
final class WorkspaceRepositoryLabelObservation {
    let updates: AsyncStream<[UUID: String]>
    private let continuation: AsyncStream<[UUID: String]>.Continuation

    init(workspaces: [Workspace]) {
        (updates, continuation) = AsyncStream.makeStream()
        continuation.yield(Self.snapshot(for: workspaces))
        continuation.finish()
    }

    static func snapshot(for workspaces: [Workspace]) -> [UUID: String] {
        Dictionary(uniqueKeysWithValues: workspaces.compactMap { workspace in
            WorkspaceRepoBadgeAppearanceResolver.repositoryName(
                repoRootPath: workspace.extensionSidebarProjectRootPath
            ).map { (workspace.id, $0) }
        })
    }

    func cancel() {
        continuation.finish()
    }
}
