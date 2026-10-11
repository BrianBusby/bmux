public import SwiftUI

/// Styles native buttons without replacing their keyboard or accessibility behavior.
///
/// Supply a label at least ``MatteLayoutMetrics/minimumHitSize`` points tall.
public struct MatteButtonStyle: ButtonStyle {
    private let role: MatteControlRole
    private let theme: MatteTheme
    private let dimsWhenDisabled: Bool
    private let isSelected: Bool

    /// Creates a raised, flat, or link control using the caller's effective theme.
    /// - Parameters:
    ///   - role: Visual treatment; fields use `matteField` instead.
    ///   - theme: Resolved appearance tokens.
    ///   - dimsWhenDisabled: Whether this control owns disabled opacity. Pass false
    ///     when an enclosing disabled card already dims its content.
    ///   - isSelected: Whether a raised toggle remains active, including while pressed.
    public init(_ role: MatteControlRole = .raised, theme: MatteTheme, dimsWhenDisabled: Bool = true, isSelected: Bool = false) {
        self.role = role
        self.theme = theme
        self.dimsWhenDisabled = dimsWhenDisabled
        self.isSelected = isSelected
    }

    /// Builds native button feedback from SwiftUI's press state.
    /// - Parameter configuration: The original label and native press state.
    /// - Returns: A decorated label that retains native button activation.
    public func makeBody(configuration: Configuration) -> some View {
        MatteButtonLabel(configuration: configuration, role: role, theme: theme, dimsWhenDisabled: dimsWhenDisabled, isSelected: isSelected)
    }
}
