public import Foundation

/// A read-only render-health row for one surface in the `surface.health` payload.
///
/// Mirrors the per-surface dictionary the `surface.health` body builds. The
/// `inWindow` value is optional: the app writes a Bool for panel types with a
/// native render-window signal and `nil` for panel types that do not expose one.
/// The coordinator mints the surface ref and writes the index.
public struct ControlSurfaceHealthEntry: Sendable, Equatable {
    /// The surface's panel identifier.
    public let surfaceID: UUID
    /// The panel type's raw value.
    public let typeRawValue: String
    /// Whether the surface's hosting view is in a window: a Bool for terminal
    /// (`isViewInWindow`), browser (`webView.window != nil`), and agent-session
    /// (`rendererSession.isViewInWindow`) panels, `nil` (JSON `null`) for any
    /// panel type that does not expose a native render-window signal.
    public let inWindow: Bool?

    /// Creates a surface-health entry.
    ///
    /// - Parameters:
    ///   - surfaceID: The surface's panel identifier.
    ///   - typeRawValue: The panel type's raw value.
    ///   - inWindow: Whether the surface's hosting view is in a window, or `nil`
    ///     for panel types without a native render-window signal.
    public init(
        surfaceID: UUID,
        typeRawValue: String,
        inWindow: Bool?
    ) {
        self.surfaceID = surfaceID
        self.typeRawValue = typeRawValue
        self.inWindow = inWindow
    }
}
