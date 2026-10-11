import SwiftUI

extension EnvironmentValues {
    var matteButtonHitExpansion: CGFloat {
        get { self[MatteButtonHitExpansionKey.self] }
        set { self[MatteButtonHitExpansionKey.self] = newValue }
    }

    /// Local focus of a MatteButton, shared only with its visual button style.
    var matteButtonIsFocused: Bool {
        get { self[MatteButtonFocusKey.self] }
        set { self[MatteButtonFocusKey.self] = newValue }
    }
}

private struct MatteButtonFocusKey: EnvironmentKey {
    static let defaultValue = false
}

private struct MatteButtonHitExpansionKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}
