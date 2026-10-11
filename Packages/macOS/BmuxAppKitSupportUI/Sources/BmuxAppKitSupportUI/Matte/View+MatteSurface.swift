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
    ///   - fill: An already-resolved content background, such as a configured terminal
    ///     color. When omitted, the semantic surface token supplies the fill.
    /// - Returns: The original content with a noninteractive decorative background.
    public func matteSurface(
        _ role: MatteSurfaceRole, theme: MatteTheme, state: MatteSurfaceState = .init(), fill: Color? = nil
    ) -> some View {
        background {
            MatteSurfaceDecoration(role: role, theme: theme, state: state, fill: fill)
                .compositingGroup()
                .opacity(role == .card && !state.isEnabled ? theme.layout.disabledOpacity : 1)
        }
    }
}
