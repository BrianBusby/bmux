import Foundation

@_spi(BmuxHostTransport)
/// Host-side callbacks used by the sidebar XPC bridge.
public struct BmuxSidebarHostClient: Sendable {
    /// Returns the latest host snapshot that should be sent to an extension.
    public var snapshot: @Sendable () async throws -> BmuxSidebarSnapshot

    /// Dispatches a sidebar action from an extension into BMUX.
    public var dispatch: @Sendable (BmuxSidebarAction) async throws -> BmuxSidebarActionResult

    /// Creates a host client from snapshot and action-dispatch closures.
    public init(
        snapshot: @escaping @Sendable () async throws -> BmuxSidebarSnapshot,
        dispatch: @escaping @Sendable (BmuxSidebarAction) async throws -> BmuxSidebarActionResult
    ) {
        self.snapshot = snapshot
        self.dispatch = dispatch
    }
}
