import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct CommandPaletteSelectionShortcutTests {
    @Test func remappedPreviousDoesNotConsumeControlP() throws {
        try CommandPaletteShortcutSettingsFixture().withEmptySettings {
            let fixture = CommandPaletteShortcutWindowFixture()
            defer { fixture.close() }
            try fixture.prepare()
            let remapped = StoredShortcut(key: "u", command: false, shift: false, option: false, control: true)
            KeyboardShortcutSettings.setShortcut(remapped, for: .commandPalettePrevious)
            #expect(KeyboardShortcutSettings.shortcutIfBound(for: .commandPalettePrevious) == remapped)

            let controlP = try fixture.event("\u{10}", modifiers: [.control], keyCode: 35)
            #expect(!fixture.app.debugHandleCustomShortcut(event: controlP))
            // Selection notifications are synchronous: handler return is the delivery boundary.
            #expect(fixture.notificationCount == 0)
            #expect(fixture.observedDeltas.isEmpty)
            let controlU = try fixture.event("\u{15}", modifiers: [.control], keyCode: 32)
            #expect(fixture.app.debugHandleCustomShortcut(event: controlU))
            #expect(fixture.notificationCount == 1)
            #expect(fixture.observedDeltas == [-1])
            #expect(fixture.observedWindow === fixture.window)
        }
    }

    @Test func chordedNextMovesSelection() throws {
        try CommandPaletteShortcutSettingsFixture().withEmptySettings {
            let fixture = CommandPaletteShortcutWindowFixture()
            defer { fixture.close() }
            try fixture.prepare()
            KeyboardShortcutSettings.setShortcut(
                StoredShortcut(key: "b", command: false, shift: false, option: false, control: true, chordKey: "n"),
                for: .commandPaletteNext
            )
            let prefix = try fixture.event("b", modifiers: [.control], keyCode: 11)
            let action = try fixture.event("n", modifiers: [], keyCode: 45)
            #expect(fixture.app.debugHandleCustomShortcut(event: prefix))
            #expect(fixture.observedDeltas == [])
            #expect(fixture.app.debugHandleCustomShortcut(event: action))
            #expect(fixture.observedWindow?.windowNumber == fixture.window.windowNumber)
            #expect(fixture.observedDeltas == [1])
        }
    }
}
