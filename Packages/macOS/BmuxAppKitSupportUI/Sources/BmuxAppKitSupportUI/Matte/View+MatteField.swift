public import SwiftUI

extension View {
    /// Adds recessed native field chrome without changing text input or focus ownership.
    /// - Parameters:
    ///   - theme: Effective appearance tokens.
    ///   - isFocused: Focus state owned by the text field's caller.
    /// - Returns: The original field content over a noninteractive recessed surface.
    public func matteField(theme: MatteTheme, isFocused: Bool = false) -> some View {
        background {
            MatteControlDecoration(role: .field, theme: theme, state: .init(isFocused: isFocused))
        }
    }
}
