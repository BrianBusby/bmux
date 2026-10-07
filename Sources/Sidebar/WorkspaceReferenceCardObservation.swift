import Combine
import Foundation

/// Adapts existing workspace notifications into immutable cards above the list boundary.
@MainActor
final class WorkspaceReferenceCardObservation {
    let updates: AsyncStream<[WorkspaceReferenceCardSnapshot]>
    private let continuation: AsyncStream<[WorkspaceReferenceCardSnapshot]>.Continuation
    // Workspace's legacy publishers remain confined to this AsyncStream adapter.
    private var subscription: AnyCancellable?

    init(workspaces: [Workspace], project: @escaping @MainActor (Workspace) -> WorkspaceReferenceCardSnapshot) {
        let (updates, continuation) = AsyncStream<[WorkspaceReferenceCardSnapshot]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.updates = updates
        self.continuation = continuation
        continuation.yield(workspaces.map(project))
        subscription = Publishers.MergeMany(workspaces.flatMap {
            [$0.sidebarImmediateObservationPublisher, $0.sidebarObservationPublisher]
        })
        // Some legacy sources publish in willSet. Project only after storage has changed.
        .receive(on: RunLoop.main)
        .coalesceLatest(for: Workspace.sidebarImmediateObservationCoalesceInterval, scheduler: RunLoop.main)
        .map { workspaces.map(project) }
        .removeDuplicates()
        .sink { continuation.yield($0) }
    }

    func cancel() {
        subscription?.cancel()
        subscription = nil
        continuation.finish()
    }
}
