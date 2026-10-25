import Foundation
import Observation

/// Owns the cancellable exit fade before Explorer commits a new result.
@MainActor @Observable
final class WorkspaceExplorerExitTransition {
    typealias Delay = @MainActor (Duration) async throws -> Void

    private(set) var presentation: WorkspaceExplorerExitPresentation?
    private var task: Task<Void, Never>?
    private let delay: Delay

    init(delay: @escaping Delay) { self.delay = delay }

    func stage(from previous: WorkspaceExplorerProjectionResult?,
               to next: WorkspaceExplorerProjectionResult?,
               scope: WorkspaceExplorerScope,
               filters: [WorkspaceExplorerDimension: WorkspaceExplorerGroupKey],
               animated: Bool) {
        cancel()
        guard animated, let previous, let next else { return }
        let workspaces = Set(previous.visibleWorkspaceIDs).subtracting(next.visibleWorkspaceIDs)
        guard !workspaces.isEmpty else { return }
        presentation = WorkspaceExplorerExitPresentation(result: previous, scope: scope,
            filters: filters, exitingWorkspaceIDs: workspaces)
        // The fade duration is an intentional, bounded presentation delay with cancellation.
        task = Task { [delay] in
            do { try await delay(.milliseconds(170)) } catch { return }
            guard !Task.isCancelled else { return }
            presentation = nil
            task = nil
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        presentation = nil
    }
}
