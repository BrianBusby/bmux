import Foundation

/// In-process sidebar provider used by BMUX-owned sidebar presentations.
public protocol BmuxSidebarProvider: Sendable {
    /// Stable metadata describing the provider in selection UI.
    var descriptor: BmuxSidebarProviderDescriptor { get }

    /// Builds a render model from the latest sidebar snapshot.
    func render(snapshot: BmuxSidebarProviderSnapshot) -> BmuxSidebarProviderRenderModel
}
