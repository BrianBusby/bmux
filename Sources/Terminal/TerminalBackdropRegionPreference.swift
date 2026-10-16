import SwiftUI

/// Carries visible terminal-canvas bounds above Bonsplit's separate native hosting roots.
struct TerminalBackdropRegionPreference: PreferenceKey {
    static let defaultValue: [Anchor<CGRect>] = []

    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value.append(contentsOf: nextValue())
    }
}
