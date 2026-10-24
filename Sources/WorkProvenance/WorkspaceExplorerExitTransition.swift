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
               exitsUnassigned: Bool,
               animated: Bool) {
        cancel()
        guard animated, let previous, let next else { return }
        let projects = Set(previous.visibleProjectIDs).subtracting(next.visibleProjectIDs)
        let workspaces = Set(previous.visibleWorkspaceIDs).subtracting(next.visibleWorkspaceIDs)
        guard !projects.isEmpty || !workspaces.isEmpty || exitsUnassigned else { return }
        presentation = WorkspaceExplorerExitPresentation(result: previous, scope: scope,
            filters: filters, exitingProjectIDs: projects, exitsUnassigned: exitsUnassigned,
            exitingWorkspaceIDs: workspaces)
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
