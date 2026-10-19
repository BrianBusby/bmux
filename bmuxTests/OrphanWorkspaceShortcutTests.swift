import AppKit
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite
struct OrphanWorkspaceShortcutTests {
    @Test
    func remappedCommandTPrunesWindowlessContextWithoutAddingToItsManager() throws {
        try OrphanWorkspaceShortcutSettingsFixture().withCommandT {
            let fixture = OrphanWorkspaceShortcutFixture()
            defer { fixture.close() }
            #expect(fixture.app.mainWindow(for: fixture.orphanWindowID) == nil)
            #expect(fixture.app.tabManager === fixture.orphanManager)
            let orphanCount = fixture.orphanManager.tabs.count
            let event = try #require(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [.command],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0,
                context: nil, characters: "t", charactersIgnoringModifiers: "t",
                isARepeat: false, keyCode: 17
            ))
            #expect(fixture.app.debugHandleCustomShortcut(event: event))
            #expect(fixture.orphanManager.tabs.count == orphanCount)
            #expect(fixture.app.tabManagerFor(windowId: fixture.orphanWindowID) == nil)
            #expect(fixture.app.tabManager === fixture.liveManager)
            #expect(Set(fixture.app.mainWindowContexts.keys) == [ObjectIdentifier(fixture.window)])
            #expect(!fixture.window.isVisible)
        }
    }
}
