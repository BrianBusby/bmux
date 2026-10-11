import AppKit
import SwiftUI
import Testing
@testable import BmuxAppKitSupportUI

@MainActor
@Suite struct MatteButtonFocusTests {
    @Test func localActivationLeavesModifiedShortcutsAndDisabledControlsAlone() {
        #expect(MatteButton<Text>.acceptsKeyboardActivation(isEnabled: true, modifiers: []))
        #expect(!MatteButton<Text>.acceptsKeyboardActivation(isEnabled: false, modifiers: []))
        for modifier: EventModifiers in [.command, .control, .option, .shift, [.command, .shift]] {
            #expect(!MatteButton<Text>.acceptsKeyboardActivation(isEnabled: true, modifiers: modifier))
        }
    }

    @Test func expandedNativeButtonKeepsTheSameOuterLayoutSize() {
        let theme = MatteTheme(colorScheme: .dark)
        func size(expansion: CGFloat) -> CGSize {
            let host = NSHostingView(rootView:
                MatteButton(hitExpansion: expansion, action: {}) {
                    Color.clear.frame(width: theme.layout.raisedHitSize, height: theme.layout.raisedHitSize)
                }
                .buttonStyle(MatteButtonStyle(theme: theme)))
            return host.fittingSize
        }
        #expect(size(expansion: 0) == size(expansion: theme.layout.invisibleHitExpansion))
    }

    private func makeWindow() -> NSWindow {
        NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.titled], backing: .buffered, defer: false)
    }
}
