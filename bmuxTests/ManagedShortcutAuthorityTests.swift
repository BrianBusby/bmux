import Foundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite(.serialized)
@MainActor
struct ManagedShortcutAuthorityTests {
    private let edited = StoredShortcut(key: "n", command: true, shift: false, option: false, control: false)
    private let managed = StoredShortcut(key: "b", command: false, shift: false, option: false, control: true, chordKey: "c")

    @Test func settingsFileTakesPrecedenceOverPersistedShortcut() throws {
        try ManagedShortcutSettingsFixture().withStores { emptyStore, managedStore in
            KeyboardShortcutSettings.setShortcut(edited, for: .newTab)
            #expect(KeyboardShortcutSettings.shortcut(for: .newTab) == edited)
            let persisted = try #require(UserDefaults.standard.data(forKey: KeyboardShortcutSettings.Action.newTab.defaultsKey))
            #expect(try JSONDecoder().decode(StoredShortcut.self, from: persisted) == edited)

            KeyboardShortcutSettings.settingsFileStore = managedStore
            #expect(KeyboardShortcutSettings.isManagedBySettingsFile(.newTab))
            #expect(KeyboardShortcutSettings.shortcut(for: .newTab) == managed)
            #expect(UserDefaults.standard.data(forKey: KeyboardShortcutSettings.Action.newTab.defaultsKey) == persisted)

            KeyboardShortcutSettings.settingsFileStore = emptyStore
            #expect(!KeyboardShortcutSettings.isManagedBySettingsFile(.newTab))
            #expect(KeyboardShortcutSettings.shortcut(for: .newTab) == edited)
        }
    }

    @Test func managedShortcutIgnoresUIWritesAndRestoresDefaultWhenUnmanaged() throws {
        try ManagedShortcutSettingsFixture().withStores { emptyStore, managedStore in
            #expect(KeyboardShortcutSettings.shortcut(for: .newTab) == KeyboardShortcutSettings.Action.newTab.defaultShortcut)
            KeyboardShortcutSettings.settingsFileStore = managedStore
            #expect(KeyboardShortcutSettings.shortcut(for: .newTab) == managed)

            KeyboardShortcutSettings.setShortcut(edited, for: .newTab)
            #expect(KeyboardShortcutSettings.shortcut(for: .newTab) == managed)
            #expect(UserDefaults.standard.data(forKey: KeyboardShortcutSettings.Action.newTab.defaultsKey) == nil)
            KeyboardShortcutSettings.resetShortcut(for: .newTab)
            #expect(KeyboardShortcutSettings.shortcut(for: .newTab) == managed)

            KeyboardShortcutSettings.settingsFileStore = emptyStore
            #expect(!KeyboardShortcutSettings.isManagedBySettingsFile(.newTab))
            #expect(KeyboardShortcutSettings.shortcut(for: .newTab) == KeyboardShortcutSettings.Action.newTab.defaultShortcut)
        }
    }
}
