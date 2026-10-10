public import SwiftUI

extension View {
    /// Adds a native matte background while preserving content identity, layout, and input.
    ///
    /// The decoration does not clip or pad content, install gestures, animate, or lift
    /// cards. The caller owns those behaviors and its disabled-content presentation.
    /// Decorative layers are excluded from hit testing and accessibility.
    ///
    /// ```swift
    /// content.matteSurface(.card, theme: theme,
    ///                      state: MatteSurfaceState(isSelected: isSelected))
    /// ```
    /// - Parameters:
    ///   - role: The surface's role in the elevation hierarchy.
    ///   - theme: Tokens resolved from the caller's effective appearance.
    ///   - state: Immutable interaction values; defaults to stationary and enabled.
    /// - Returns: The original content with a noninteractive decorative background.
    public func matteSurface(
        _ role: MatteSurfaceRole, theme: MatteTheme, state: MatteSurfaceState = .init()
    ) -> some View {
        background {
            MatteSurfaceDecoration(role: role, theme: theme, state: state)
                .compositingGroup()
                .opacity(role == .card && !state.isEnabled ? theme.layout.disabledOpacity : 1)
        }
    }
}
