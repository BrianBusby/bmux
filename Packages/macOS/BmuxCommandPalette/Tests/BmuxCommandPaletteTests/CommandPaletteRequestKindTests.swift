import Foundation
import Testing

@testable import BmuxCommandPalette

@Suite struct CommandPaletteRequestKindTests {
    @Test func notificationNamesMatchLegacyLiterals() {
        #expect(CommandPaletteRequestKind.commands.notificationName == "bmux.commandPaletteRequested")
        #expect(CommandPaletteRequestKind.switcher.notificationName == "bmux.commandPaletteSwitcherRequested")
        #expect(CommandPaletteRequestKind.renameTab.notificationName == "bmux.commandPaletteRenameTabRequested")
        #expect(CommandPaletteRequestKind.renameWorkspace.notificationName == "bmux.commandPaletteRenameWorkspaceRequested")
        #expect(
            CommandPaletteRequestKind.editWorkspaceDescription.notificationName
                == "bmux.commandPaletteEditWorkspaceDescriptionRequested"
        )
    }

    @Test func everyKindMarksPending() {
        for kind in CommandPaletteRequestKind.allCases {
            #expect(kind.marksPending)
        }
    }

    @Test func notificationNamesAreDistinct() {
        let names = Set(CommandPaletteRequestKind.allCases.map(\.notificationName))
        #expect(names.count == CommandPaletteRequestKind.allCases.count)
    }
}
