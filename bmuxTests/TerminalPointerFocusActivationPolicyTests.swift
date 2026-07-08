import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct TerminalPointerFocusActivationPolicyTests {
    @Test
    func unfocusedPaneFocusClickDoesNotForwardToTerminal() {
        let policy = TerminalPointerFocusActivationPolicy()

        #expect(!policy.shouldForwardToTerminal(wasFocusedBeforePointerDown: false))
    }

    @Test
    func focusedPaneClickStillForwardsToTerminal() {
        let policy = TerminalPointerFocusActivationPolicy()

        #expect(policy.shouldForwardToTerminal(wasFocusedBeforePointerDown: true))
    }

    @Test
    func matchingFocusedPanelForwardsToTerminal() {
        let panelId = UUID()
        let policy = TerminalPointerFocusActivationPolicy()

        #expect(policy.shouldForwardToTerminal(currentPanelId: panelId, focusedPanelId: panelId))
    }

    @Test
    func differentFocusedPanelDoesNotForwardToTerminal() {
        let policy = TerminalPointerFocusActivationPolicy()

        #expect(!policy.shouldForwardToTerminal(currentPanelId: UUID(), focusedPanelId: UUID()))
    }

    @Test
    func missingFocusedPanelDoesNotForwardToTerminal() {
        let policy = TerminalPointerFocusActivationPolicy()

        #expect(!policy.shouldForwardToTerminal(currentPanelId: UUID(), focusedPanelId: nil))
    }
}
