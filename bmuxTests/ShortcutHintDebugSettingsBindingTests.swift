import BmuxFoundation
import BmuxSettings
import Testing

/// Guards the hardcoded `UserDefaults` key and default in
/// ``ShortcutHintDebugSettings`` against the canonical
/// `shortcuts.showModifierHoldHints` catalog entry. `BmuxFoundation` is a leaf
/// module and cannot import `BmuxSettings`, so the values are duplicated; this
/// suite fails if they drift.
@Suite("Shortcut hint debug settings binding")
struct ShortcutHintDebugSettingsBindingTests {
    @Test
    func keyAndDefaultMatchSettingCatalog() {
        let catalogEntry = SettingCatalog().shortcuts.showModifierHoldHints
        #expect(ShortcutHintDebugSettings.showModifierHoldHintsKey == catalogEntry.userDefaultsKey)
        #expect(ShortcutHintDebugSettings.defaultShowModifierHoldHints == catalogEntry.defaultValue)
    }
}
