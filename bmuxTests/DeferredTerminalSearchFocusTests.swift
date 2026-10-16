import AppKit
import BmuxTerminal
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct DeferredTerminalSearchFocusTests {
    @Test func searchOverlayFocusesSearchFieldAfterDeferredAttach() async throws {
        let fixture = try DeferredTerminalSearchFixture()
        defer { fixture.close() }
        try fixture.present()
        let host = fixture.panel.hostedView
        let state = TerminalSurface.SearchState(needle: "")
        fixture.panel.surface.searchState = state
        host.setSearchOverlay(searchState: state)
        let mountDeadline = ContinuousClock.now.advanced(by: .seconds(1))
        try await NativeMainQueueDelivery(duration: .seconds(1)).deliver()
        // The native FIFO follows the owner's deferred attach; layout materializes its SwiftUI field.
        host.layoutSubtreeIfNeeded()
        host.debugSearchOverlayHostingViewForTesting()?.layoutSubtreeIfNeeded()
        let field = try #require(editableField(in: host), "Expected mounted find text field")
        try #require(ContinuousClock.now <= mountDeadline, "Expected the search field within the original one-second mount bound")
        try await TerminalSearchFieldFocusObservation(duration: .seconds(1)).wait(of: field, in: fixture.window)
        #expect(owns(fixture.window.firstResponder, field: field), "Expected the search field to become first responder")
    }

    private func editableField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable { return field }
        return view.subviews.lazy.compactMap { editableField(in: $0) }.first
    }

    private func owns(_ responder: NSResponder?, field: NSTextField) -> Bool {
        if responder === field { return true }
        guard let editor = responder as? NSTextView else { return false }
        return editor.isFieldEditor && editor.delegate as? NSTextField === field
    }
}
