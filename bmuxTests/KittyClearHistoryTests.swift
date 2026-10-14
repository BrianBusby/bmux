import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Clear-history retains plain typed input after the shell resets stale Kitty state.
@MainActor
struct KittyClearHistoryTests {
    @Test func staleKittyKeyboardAfterClearHistoryDoesNotEncodePlainLetterAsCSIU() async throws {
        let fixture = try KittyClearHistoryFixture()
        defer { fixture.close() }
        try await fixture.prepare()
        #expect(try fixture.readText().contains(fixture.readyMarker), "Expected Kitty enable marker before clear-history")
        let reset = try await fixture.keyboardReset()
        #expect(reset == Data("\u{1B}[>m\u{1B}[<8u".utf8), "The shell must reset modifyOtherKeys and Kitty keyboard state")
        try fixture.processOutput(reset)
        #expect(fixture.surface.performBindingAction("clear_screen"))
        fixture.surface.forceRefresh(reason: "unit.clearHistory")
        #expect(fixture.surface.hostedView.debugSendSyntheticKeyPressAndReleaseForUITest(
            characters: "c", charactersIgnoringModifiers: "c", keyCode: 8),
            "Expected ordinary c keyDown to be dispatched through ghostty_surface_key")
        try await fixture.waitForCapture()
        let text = try fixture.readText()
        let range = try #require(text.range(of: "\(fixture.captureMarker)="), "Expected raw PTY byte capture marker")
        let hex = text[range.upperBound...].prefix { "0123456789abcdefABCDEF".contains($0) }
        #expect(String(hex) == "63", "A plain c must write one ASCII byte to PTY input, not a Kitty CSI-u sequence")
        #expect(!text.contains("c9;1:3u") && !text.contains("99;1:3u"),
                "CSI-u response bodies must not land in terminal output as printable text")
    }
}
