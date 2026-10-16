import Testing

/// A real pointer-down dismisses unread attention in the already-focused terminal.
@MainActor
struct NotificationMouseDownTests {
    @Test func mouseDownDismissesUnreadWhenSurfaceIsAlreadyFirstResponder() async throws {
        let fixture = NotificationInteractionFixture()
        defer { fixture.close() }
        try await fixture.prepare()
        let delivery = try fixture.interact(.mouseDown) { firstResponder, unreadBefore, unreadAfter in
            #expect(firstResponder)
            #expect(unreadBefore)
            #expect(!unreadAfter)
        }
        #expect(try await fixture.awaitFlash(delivery) == 1)
    }
}
