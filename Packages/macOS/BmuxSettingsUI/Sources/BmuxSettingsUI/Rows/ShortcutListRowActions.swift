import BmuxFoundation
import BmuxSettings

struct ShortcutListRowActions {
    let onStroke: (ShortcutStroke) -> Void
    let onChord: (StoredShortcut) -> Void
    let onBareKeyRejected: () -> Void
    let onClearOrRestore: () -> Void
    let onClearRejections: () -> Void
}
