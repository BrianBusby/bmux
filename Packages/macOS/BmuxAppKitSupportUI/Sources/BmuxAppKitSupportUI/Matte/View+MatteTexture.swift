public import SwiftUI

extension View {
    /// Enables optional static grain for descendant matte surfaces.
    /// Apply once above the window's list boundaries. The scope lazily loads and
    /// retains the bundled image; disabling removes grain without reloading it.
    /// - Parameter enabled: Whether to paint texture. Persistence belongs to the app.
    /// - Returns: The view with one retained, optional surface-texture scope.
    public func matteTexture(enabled: Bool) -> some View {
        modifier(MatteTextureScope(enabled: enabled))
    }
}
