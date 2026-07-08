import Foundation

/// Provider that renders with explicit render context.
public protocol BmuxContextualSidebarProvider: BmuxSidebarProvider {
    /// Builds a render model from a sidebar snapshot and render context.
    func render(snapshot: BmuxSidebarProviderSnapshot, context: BmuxSidebarProviderRenderContext) -> BmuxSidebarProviderRenderModel
}
