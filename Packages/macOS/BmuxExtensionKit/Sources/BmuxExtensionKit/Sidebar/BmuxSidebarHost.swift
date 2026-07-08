import Foundation

/// Typed command channel from a sidebar extension back to BMUX.
@MainActor
public struct BmuxSidebarHost {
    private let performAction: @MainActor @Sendable (BmuxSidebarAction, @escaping @MainActor @Sendable (BmuxSidebarActionResult) -> Void) -> BmuxSidebarActionCancellation?
    private let refreshSnapshot: @MainActor @Sendable () -> Void

    @_spi(BmuxHostTransport)
    public init(
        performAction: @escaping @MainActor @Sendable (BmuxSidebarAction, @escaping @MainActor @Sendable (BmuxSidebarActionResult) -> Void) -> Void,
        refreshSnapshot: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.performAction = { action, reply in
            performAction(action, reply)
            return nil
        }
        self.refreshSnapshot = refreshSnapshot
    }

    /// Creates a typed host channel with cancellable action dispatch.
    ///
    /// This initializer is transport SPI for BMUX's ExtensionKit runtime. SDK
    /// consumers receive `BmuxSidebarHost` through `BmuxSidebarContext`.
    @_spi(BmuxHostTransport)
    public init(
        performCancellableAction: @escaping @MainActor @Sendable (BmuxSidebarAction, @escaping @MainActor @Sendable (BmuxSidebarActionResult) -> Void) -> BmuxSidebarActionCancellation?,
        refreshSnapshot: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.performAction = performCancellableAction
        self.refreshSnapshot = refreshSnapshot
    }

    /// Requests the latest sidebar snapshot from BMUX.
    public func refresh() {
        refreshSnapshot()
    }

    /// Requests that BMUX create a workspace.
    public func createWorkspace(
        title: String? = nil,
        select: Bool = true
    ) async throws {
        try await send(.createWorkspace(title: title, workingDirectory: nil, select: select))
    }

    /// Requests that BMUX create a workspace rooted at a specific local folder.
    ///
    /// This requires the `.createWorkspaceWithPath` action scope in addition to
    /// `.createWorkspace`.
    public func createWorkspace(
        title: String? = nil,
        at workingDirectory: String,
        select: Bool = true
    ) async throws {
        try await send(.createWorkspace(title: title, workingDirectory: workingDirectory, select: select))
    }

    /// Selects a workspace in BMUX.
    public func selectWorkspace(_ id: UUID) async throws {
        try await send(.selectWorkspace(id))
    }

    /// Requests that BMUX close a workspace.
    public func closeWorkspace(_ id: UUID) async throws {
        try await send(.closeWorkspace(id))
    }

    /// Selects the next workspace in BMUX's current sidebar order.
    public func selectNextWorkspace() async throws {
        try await send(.selectNextWorkspace)
    }

    /// Selects the previous workspace in BMUX's current sidebar order.
    public func selectPreviousWorkspace() async throws {
        try await send(.selectPreviousWorkspace)
    }

    /// Requests that BMUX open a web URL.
    public func openURL(_ url: URL) async throws {
        try await send(.openURL(url.absoluteString))
    }

    /// Requests that BMUX create a terminal surface.
    ///
    /// Extensions can ask BMUX to create the surface, but cannot seed shell
    /// input. This keeps `.createSurface` separate from command execution.
    public func createTerminalSurface(in workspaceID: UUID? = nil) async throws {
        try await send(.createTerminalSurface(workspaceID: workspaceID))
    }

    public func createBrowserSurface(
        in workspaceID: UUID? = nil,
        url: URL? = nil
    ) async throws {
        try await send(.createBrowserSurface(workspaceID: workspaceID, url: url?.absoluteString))
    }

    public func selectSurface(workspaceID: UUID, surfaceID: UUID) async throws {
        try await send(.selectSurface(workspaceID: workspaceID, surfaceID: surfaceID))
    }

    public func selectNextSurface() async throws {
        try await send(.selectNextSurface)
    }

    public func selectPreviousSurface() async throws {
        try await send(.selectPreviousSurface)
    }

    public func closeSurface(workspaceID: UUID, surfaceID: UUID) async throws {
        try await send(.closeSurface(workspaceID: workspaceID, surfaceID: surfaceID))
    }

    public func splitTerminal(
        workspaceID: UUID,
        surfaceID: UUID,
        direction: BmuxSidebarSplitDirection
    ) async throws {
        try await send(.splitTerminal(workspaceID: workspaceID, surfaceID: surfaceID, direction: direction))
    }

    public func splitBrowser(
        workspaceID: UUID,
        surfaceID: UUID,
        direction: BmuxSidebarSplitDirection,
        url: URL? = nil
    ) async throws {
        try await send(.splitBrowser(workspaceID: workspaceID, surfaceID: surfaceID, direction: direction, url: url?.absoluteString))
    }

    public func toggleSurfaceZoom(workspaceID: UUID, surfaceID: UUID) async throws {
        try await send(.toggleSurfaceZoom(workspaceID: workspaceID, surfaceID: surfaceID))
    }

    private func send(_ action: BmuxSidebarAction) async throws {
        let result = await perform(action)
        guard result.accepted else {
            let message = result.message ?? "bmux did not allow that action"
            if result.rejectionReason == .cancelled {
                throw BmuxSidebarActionError.cancelled
            }
            throw BmuxSidebarActionError.rejected(message)
        }
    }

    /// Sends a raw sidebar action and returns BMUX's acceptance result.
    @_spi(BmuxHostTransport)
    public func perform(_ action: BmuxSidebarAction) async -> BmuxSidebarActionResult {
        let replyGate = BmuxSidebarActionReplyGate()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                Task { @MainActor in
                    guard replyGate.setContinuation(continuation) else { return }
                    let cancellation = performAction(action) { result in
                        replyGate.resume(returning: result)
                    }
                    replyGate.setCancellation(cancellation)
                }
            }
        } onCancel: {
            replyGate.cancel()
        }
    }

    /// Sends a raw sidebar action. Prefer the async typed helpers above when possible.
    @_spi(BmuxHostTransport)
    public func perform(
        _ action: BmuxSidebarAction,
        reply: @escaping @MainActor @Sendable (BmuxSidebarActionResult) -> Void
    ) {
        _ = performAction(action, reply)
    }
}

private final class BmuxSidebarActionReplyGate: @unchecked Sendable {
    // The host transport completes actions through escaping XPC callbacks while
    // task cancellation can arrive from any executor. A small lock keeps the
    // continuation and transport cancellation token single-resume without
    // adding actor hops to the callback path.
    private let lock = NSLock()
    private var continuation: CheckedContinuation<BmuxSidebarActionResult, Never>?
    private var cancellation: BmuxSidebarActionCancellation?
    private var didComplete = false

    func setContinuation(_ continuation: CheckedContinuation<BmuxSidebarActionResult, Never>) -> Bool {
        lock.lock()
        if didComplete {
            lock.unlock()
            continuation.resume(returning: .cancelled)
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func setCancellation(_ cancellation: BmuxSidebarActionCancellation?) {
        lock.lock()
        if didComplete {
            lock.unlock()
            cancellation?.cancel()
            return
        }
        self.cancellation = cancellation
        lock.unlock()
    }

    func resume(returning result: BmuxSidebarActionResult) {
        let continuation = complete()
        continuation?.resume(returning: result)
    }

    func cancel() {
        let cancellation: BmuxSidebarActionCancellation?
        let continuation: CheckedContinuation<BmuxSidebarActionResult, Never>?
        lock.lock()
        if didComplete {
            lock.unlock()
            return
        }
        didComplete = true
        cancellation = self.cancellation
        continuation = self.continuation
        self.cancellation = nil
        self.continuation = nil
        lock.unlock()

        cancellation?.cancel()
        continuation?.resume(returning: .cancelled)
    }

    private func complete() -> CheckedContinuation<BmuxSidebarActionResult, Never>? {
        lock.lock()
        if didComplete {
            lock.unlock()
            return nil
        }
        didComplete = true
        let continuation = self.continuation
        self.continuation = nil
        self.cancellation = nil
        lock.unlock()
        return continuation
    }
}
