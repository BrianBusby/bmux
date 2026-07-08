import Foundation

/// Provider that can both render sidebar state and handle host mutations.
public protocol BmuxMutableSidebarProvider: BmuxContextualSidebarProvider {
    /// Handles a mutation against the latest sidebar snapshot.
    func handle(
        _ mutation: BmuxSidebarProviderMutation,
        snapshot: BmuxSidebarProviderSnapshot
    ) throws -> BmuxSidebarProviderCommandResult
}
