import Combine
import Foundation

/// Value snapshots of repository names for a workspace list; cancel when its consumer leaves.
@MainActor
final class WorkspaceRepositoryLabelObservation {
    let updates: AsyncStream<[UUID: String]>
    private let continuation: AsyncStream<[UUID: String]>.Continuation
    // Workspace exposes discovery through @Published; confine that legacy adapter behind AsyncStream.
    private var subscription: AnyCancellable?

    init(workspaces: [Workspace]) {
        let (updates, continuation) = AsyncStream<[UUID: String]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.updates = updates
        self.continuation = continuation
        var names = Self.snapshot(for: workspaces)
        continuation.yield(names)
        subscription = Publishers.MergeMany(workspaces.map { workspace in
            workspace.$extensionSidebarProjectRootPath
                .removeDuplicates()
                .dropFirst()
                .map { root in
                    (workspace.id, WorkspaceRepoBadgeAppearanceResolver.repositoryName(repoRootPath: root))
                }
                .eraseToAnyPublisher()
        }).sink { workspaceID, name in
            // @Published emits in willSet; use its value instead of rereading the old root.
            names[workspaceID] = name
            continuation.yield(names)
        }
    }

    static func snapshot(for workspaces: [Workspace]) -> [UUID: String] {
        Dictionary(uniqueKeysWithValues: workspaces.compactMap { workspace in
            WorkspaceRepoBadgeAppearanceResolver.repositoryName(
                repoRootPath: workspace.extensionSidebarProjectRootPath
            ).map { (workspace.id, $0) }
        })
    }

    func cancel() {
        subscription?.cancel()
        subscription = nil
        continuation.finish()
    }
}
