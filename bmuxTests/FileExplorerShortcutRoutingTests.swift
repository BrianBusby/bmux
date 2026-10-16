import AppKit
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct FileExplorerShortcutRoutingTests {
    @Test func openSelectionPaneFocusPreventsNonBrowserShortcutShadowing() throws {
        try FileExplorerShortcutSettingsFixture().withEmptySettings {
            let fixture = FileExplorerShortcutRoutingFixture()
            defer { fixture.close() }
            var commitCount = 0
            fixture.table.onCommit = { commitCount += 1 }
            #expect(fixture.window.makeFirstResponder(fixture.table))
            #expect(fixture.window.firstResponder === fixture.table)

            let commandR = StoredShortcut(key: "r", command: true, shift: false, option: false, control: false)
            KeyboardShortcutSettings.setShortcut(commandR, for: .fileExplorerOpenSelection)
            let event = try fixture.event(shortcut: commandR)
            defer { fixture.app.clearShortcutEventFocusContextCache(for: event) }

            #expect(!fixture.app.shortcutWhenClauseAllows(action: .fileExplorerOpenSelection, event: event))
            #expect(fixture.app.shortcutWhenClauseAllows(action: .renameTab, event: event))
            #expect(event.isFileExplorerOpenSelectionShortcut(in: FileExplorerPanelPlacement.pane))
            #expect(fixture.app.handleConfiguredShortcutKeyEquivalent(event))
            #expect(commitCount == 1)
        }
    }

    @Test func openSelectionDispatchesFromFileExplorerChildFirstResponder() throws {
        try FileExplorerShortcutSettingsFixture().withEmptySettings {
            let fixture = FileExplorerShortcutRoutingFixture()
            defer { fixture.close() }
            fixture.table.addSubview(fixture.childButton)
            var commitCount = 0
            fixture.table.onCommit = { commitCount += 1 }
            #expect(fixture.window.makeFirstResponder(fixture.childButton))
            #expect(fixture.window.firstResponder === fixture.childButton)

            let event = try fixture.event(shortcut: KeyboardShortcutSettings.Action.fileExplorerOpenSelection.defaultShortcut)
            defer { fixture.app.clearShortcutEventFocusContextCache(for: event) }

            #expect(fixture.app.handleConfiguredShortcutKeyEquivalent(event))
            #expect(commitCount == 1)
        }
    }
}
