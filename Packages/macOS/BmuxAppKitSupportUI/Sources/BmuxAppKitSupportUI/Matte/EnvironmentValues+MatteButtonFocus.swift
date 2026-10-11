public import SwiftUI

extension EnvironmentValues {
    /// Whether keyboard input, rather than pointer input, owns visible focus chrome.
    /// This affects decoration only; native focus and actions remain unchanged.
    public var matteKeyboardFocusVisible: Bool {
        get { self[MatteKeyboardFocusVisibleKey.self] }
        set { self[MatteKeyboardFocusVisibleKey.self] = newValue }
    }

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

private struct MatteKeyboardFocusVisibleKey: EnvironmentKey {
    static let defaultValue = true
}
