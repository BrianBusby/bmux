#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

extension MobileHostConnection {
    /// Joins the current response tasks even when the operation closes the connection.
    func drainResponsesWhilePerformingForTesting(
        _ operation: @escaping @Sendable () async throws -> Void
    ) async throws {
        // Inherit this actor explicitly. The operation cannot run until the
        // same-actor drain below snapshots responseTasks and first suspends.
        // close() clears that map, so an outer test Task cannot own this ordering.
        let operationTask = Task {
            _ = self.isSubscribed(to: "terminal.updated")
            try await operation()
        }
        try await withTaskCancellationHandler {
            await debugDrainResponseTasksForTesting()
            try await operationTask.value
        } onCancel: {
            operationTask.cancel()
        }
    }
}
