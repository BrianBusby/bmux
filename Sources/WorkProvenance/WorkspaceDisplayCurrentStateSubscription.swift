import Foundation

/// Subscribes tab display state to external PE Current State changes.
@MainActor
final class WorkspaceDisplayCurrentStateSubscription {
    typealias ChangeStream = @MainActor () -> AsyncStream<Void>
    typealias StableWorkspaceIDs = @MainActor () -> [UUID]
    typealias Refresh = @MainActor ([UUID]) -> Void

    private let changeStream: ChangeStream
    private let coalescer: NotificationBurstCoalescer
    private let fileWatcher: WorkspaceDisplayCurrentStateFileWatcher?
    private var subscriptionTask: Task<Void, Never>?

    init(
        databaseURL: URL,
        changeStream: ChangeStream? = nil,
        coalescer: NotificationBurstCoalescer? = nil
    ) {
        if let changeStream {
            self.changeStream = changeStream
            self.fileWatcher = nil
        } else {
            let fileWatcher = WorkspaceDisplayCurrentStateFileWatcher(databaseURL: databaseURL)
            self.changeStream = {
                fileWatcher.changes()
            }
            self.fileWatcher = fileWatcher
        }
        self.coalescer = coalescer ?? NotificationBurstCoalescer()
    }

    deinit {
        subscriptionTask?.cancel()
    }

    func start(
        stableWorkspaceIDs: @escaping StableWorkspaceIDs,
        refresh: @escaping Refresh
    ) {
        guard subscriptionTask == nil else { return }
        let changeStream = changeStream
        let coalescer = coalescer
        subscriptionTask = Task { @MainActor in
            for await _ in changeStream() {
                guard !Task.isCancelled else { return }
                coalescer.signal {
                    let ids = stableWorkspaceIDs()
                    guard !ids.isEmpty else { return }
                    refresh(ids)
                }
            }
        }
    }

    func stop() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
        fileWatcher?.stop()
    }
}
