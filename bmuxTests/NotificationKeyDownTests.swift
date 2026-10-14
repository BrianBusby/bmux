import Testing

/// A real F1 interaction dismisses the already-focused terminal's unread attention.
@MainActor
struct NotificationKeyDownTests {
    @Test func keyDownDismissesUnreadWhenSurfaceIsAlreadyFirstResponder() async throws {
        let fixture = NotificationKeyDownFixture()
        defer { fixture.close() }
        try await fixture.prepare()
        let delivery = try fixture.pressF1 { firstResponder, unreadBefore, unreadAfter in
            #expect(firstResponder)
            #expect(unreadBefore)
            #expect(!unreadAfter)
        }
        #expect(try await fixture.awaitFlash(delivery) == 1)
    }
}
