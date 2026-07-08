import Foundation

public extension BmuxSidebarProvider {
    /// Builds the default empty render model for providers that do not implement rendering.
    func render(snapshot: BmuxSidebarProviderSnapshot) -> BmuxSidebarProviderRenderModel {
        BmuxSidebarProviderRenderModel(
            providerId: descriptor.id,
            snapshotSequence: snapshot.sequence,
            sections: []
        )
    }

    /// Builds a render model using contextual rendering when available.
    func render(
        snapshot: BmuxSidebarProviderSnapshot,
        context: BmuxSidebarProviderRenderContext
    ) -> BmuxSidebarProviderRenderModel {
        render(snapshot: snapshot)
    }
}
