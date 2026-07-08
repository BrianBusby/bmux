import AppKit

enum FindFocusNotificationKey {
    static let selectAll = "bmux.find.selectAll"
}

func bmuxClampedFindSelection(_ range: NSRange, in text: String) -> NSRange {
    let textLength = text.utf16.count
    guard range.location != NSNotFound else {
        return NSRange(location: textLength, length: 0)
    }
    let location = min(max(range.location, 0), textLength)
    let length = min(max(range.length, 0), textLength - location)
    return NSRange(location: location, length: length)
}

func bmuxTextFieldIsFirstResponder(_ field: NSTextField, in window: NSWindow) -> Bool {
    let firstResponder = window.firstResponder
    if firstResponder === field { return true }
    if let editor = field.currentEditor() as? NSTextView, firstResponder === editor { return true }
    return (firstResponder as? NSTextView).flatMap { bmuxFieldEditorOwnerView($0) } === field
}

private let bmuxFindSelectionChangingCommands: Set<String> = [
    "moveLeft:",
    "moveRight:",
    "moveBackward:",
    "moveForward:",
    "moveUp:",
    "moveDown:",
    "moveWordLeft:",
    "moveWordRight:",
    "moveWordBackward:",
    "moveWordForward:",
    "moveToBeginningOfLine:",
    "moveToEndOfLine:",
    "moveToBeginningOfDocument:",
    "moveToEndOfDocument:",
    "moveLeftAndModifySelection:",
    "moveRightAndModifySelection:",
    "moveBackwardAndModifySelection:",
    "moveForwardAndModifySelection:",
    "moveUpAndModifySelection:",
    "moveDownAndModifySelection:",
    "moveWordLeftAndModifySelection:",
    "moveWordRightAndModifySelection:",
    "moveWordBackwardAndModifySelection:",
    "moveWordForwardAndModifySelection:",
    "moveToBeginningOfLineAndModifySelection:",
    "moveToEndOfLineAndModifySelection:",
    "moveToBeginningOfDocumentAndModifySelection:",
    "moveToEndOfDocumentAndModifySelection:",
    "selectAll:",
]

func bmuxFindCommandMayChangeSelection(_ selector: Selector) -> Bool {
    bmuxFindSelectionChangingCommands.contains(NSStringFromSelector(selector))
}

func bmuxFindEventIsPlainEscape(_ event: NSEvent) -> Bool {
    ShortcutStroke.normalizedModifierFlags(from: event.modifierFlags).isEmpty && ShortcutStroke.isEscapeCancelEvent(event)
}

private let bmuxFindSelectionStore = NSMapTable<AnyObject, NSValue>.weakToStrongObjects()
private let bmuxFindFieldEditorOwners = NSMapTable<NSTextView, FindSelectionTrackingTextField>.weakToWeakObjects()

func bmuxStoredFindSelection(for owner: AnyObject?) -> NSRange? {
    guard let owner else { return nil }
    return bmuxFindSelectionStore.object(forKey: owner)?.rangeValue
}

func bmuxStoreFindSelection(_ range: NSRange, for owner: AnyObject?) {
    guard let owner else { return }
    bmuxFindSelectionStore.setObject(NSValue(range: range), forKey: owner)
}

func bmuxTrackedFindFieldEditorOwner(_ editor: NSTextView) -> FindSelectionTrackingTextField? {
    guard editor.isFieldEditor else { return nil }
    return bmuxFindFieldEditorOwners.object(forKey: editor)
}

func bmuxFindTextFieldOwner(for responder: NSResponder?) -> FindSelectionTrackingTextField? {
    if let field = responder as? FindSelectionTrackingTextField {
        return field
    }
    if let editor = responder as? NSTextView {
        return bmuxTrackedFindFieldEditorOwner(editor) ?? (bmuxFieldEditorOwnerView(editor) as? FindSelectionTrackingTextField)
    }
    return nil
}

@MainActor
func bmuxRememberFindSelectionBeforePanelFocusMove(tabManager: TabManager?, window: NSWindow?) {
    guard let editor = window?.firstResponder as? NSTextView else { return }
    let selection = bmuxClampedFindSelection(editor.selectedRange(), in: editor.string)
    if let field = bmuxTrackedFindFieldEditorOwner(editor),
       let owner = field.bmuxSelectionOwner {
        _ = field.bmuxRememberSelection(selection, in: editor.string)
        bmuxStoreFindSelection(selection, for: owner)
        return
    }
    guard let workspace = tabManager?.selectedWorkspace,
          let focusedPanelId = workspace.focusedPanelId else { return }
    let owner = (workspace.terminalPanel(for: focusedPanelId)?.searchState as AnyObject?) ?? (workspace.browserPanel(for: focusedPanelId)?.searchState as AnyObject?)
    guard let owner else { return }
    bmuxStoreFindSelection(selection, for: owner)
}

@discardableResult
func bmuxApplyFindFocusSelection(
    field: FindSelectionTrackingTextField,
    selectAll: Bool,
    alreadyFocused: Bool,
    rememberedRange: NSRange?
) -> NSRange? {
    guard let editor = field.currentEditor() as? NSTextView, !editor.hasMarkedText() else { return nil }
    if selectAll {
        let selection = field.bmuxRememberSelection(NSRange(location: 0, length: editor.string.utf16.count), in: editor.string)
        editor.setSelectedRange(selection)
        return selection
    }
    guard !alreadyFocused, let rememberedRange else { return nil }
    let selection = field.bmuxRememberSelection(rememberedRange, in: editor.string)
    editor.setSelectedRange(selection)
    return selection
}

@discardableResult
func bmuxRememberFindSelection(in root: NSView?) -> NSRange? {
    guard let root else { return nil }
    if let field = root as? FindSelectionTrackingTextField,
       let selection = field.bmuxRememberSelectionFromCurrentEditor() {
        return selection
    }
    for subview in root.subviews {
        if let selection = bmuxRememberFindSelection(in: subview) {
            return selection
        }
    }
    return nil
}

func bmuxFindResponderSnapshot() -> [String: String] {
    let responder = (NSApp.keyWindow ?? NSApp.mainWindow)?.firstResponder
    var updates: [String: String] = [
        "firstResponderType": responder.map { String(describing: type(of: $0)) } ?? "",
        "firstResponderIdentifier": (responder as? NSView)?.identifier?.rawValue ?? "",
    ]
    if let textView = responder as? NSTextView {
        updates["firstResponderSelectedRange"] = NSStringFromRange(textView.selectedRange())
        if let owner = bmuxFieldEditorOwnerView(textView) {
            updates["fieldEditorOwnerType"] = String(describing: type(of: owner))
            updates["fieldEditorOwnerIdentifier"] = owner.identifier?.rawValue ?? ""
        }
    }
    return updates
}

class FindSelectionTrackingTextField: NSTextField {
    var bmuxLastSelectedRange: NSRange?
    weak var bmuxSelectionOwner: AnyObject?
    var bmuxOnEscape: ((NSTextView) -> Bool)?
    private var bmuxSelectionObserver: NSObjectProtocol?
    private var bmuxKeyMonitor: Any?
    private weak var bmuxObservedEditor: NSTextView?
    private weak var bmuxPreviousEditorNextResponder: NSResponder?

    deinit {
        bmuxDetachSelectionObserver()
        bmuxRemoveKeyMonitor()
    }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }
        bmuxAttachSelectionObserverIfNeeded()
        bmuxRestoreRememberedSelection()
        return true
    }

    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        bmuxAttachSelectionObserverIfNeeded()
        bmuxInstallKeyMonitorIfNeeded()
        if bmuxLastSelectedRange == nil, bmuxStoredFindSelection(for: bmuxSelectionOwner) == nil {
            _ = bmuxRememberSelectionFromCurrentEditor()
        }
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        _ = bmuxRememberSelectionFromCurrentEditor()
    }

    override func textDidEndEditing(_ notification: Notification) {
        _ = bmuxRememberSelectionFromCurrentEditor()
        bmuxRemoveKeyMonitor()
        bmuxDetachSelectionObserver()
        super.textDidEndEditing(notification)
    }

    override func cancelOperation(_ sender: Any?) {
        if let editor = currentEditor() as? NSTextView, !editor.hasMarkedText(), bmuxOnEscape?(editor) == true {
            return
        }
        super.cancelOperation(sender)
    }

    func bmuxRememberSelection(_ range: NSRange, in text: String) -> NSRange {
        let selection = bmuxClampedFindSelection(range, in: text)
        bmuxLastSelectedRange = selection
        bmuxStoreFindSelection(selection, for: bmuxSelectionOwner)
        return selection
    }

    func bmuxRememberSelection(from textView: NSTextView) -> NSRange {
        bmuxRememberSelection(textView.selectedRange(), in: textView.string)
    }

    func bmuxRememberSelectionFromCurrentEditor() -> NSRange? {
        guard let editor = currentEditor() as? NSTextView else { return nil }
        return bmuxRememberSelection(from: editor)
    }

    private func bmuxAttachSelectionObserverIfNeeded() {
        guard let editor = currentEditor() as? NSTextView else { return }
        if let bmuxObservedEditor, bmuxObservedEditor !== editor {
            bmuxDetachSelectionObserver()
        }
        bmuxAdoptFieldEditor(editor)
        guard bmuxSelectionObserver == nil else { return }
        bmuxSelectionObserver = NotificationCenter.default.addObserver(
            forName: NSTextView.didChangeSelectionNotification,
            object: editor,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let textView = notification.object as? NSTextView else { return }
            _ = self.bmuxRememberSelection(from: textView)
        }
    }

    private func bmuxDetachSelectionObserver() {
        if let bmuxSelectionObserver {
            NotificationCenter.default.removeObserver(bmuxSelectionObserver)
            self.bmuxSelectionObserver = nil
        }
        if let editor = bmuxObservedEditor {
            if editor.nextResponder === self {
                editor.nextResponder = bmuxPreviousEditorNextResponder
            }
            if bmuxTrackedFindFieldEditorOwner(editor) === self {
                bmuxFindFieldEditorOwners.removeObject(forKey: editor)
            }
        }
        bmuxPreviousEditorNextResponder = nil
        bmuxObservedEditor = nil
    }

    private func bmuxAdoptFieldEditor(_ editor: NSTextView) {
        bmuxObservedEditor = editor
        bmuxFindFieldEditorOwners.setObject(self, forKey: editor)
        if editor.nextResponder !== self {
            bmuxPreviousEditorNextResponder = editor.nextResponder
            editor.nextResponder = self
        }
        bmuxInstallKeyMonitorIfNeeded()
    }

    private func bmuxInstallKeyMonitorIfNeeded() {
        guard bmuxKeyMonitor == nil else { return }
        bmuxKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let eventWindow = event.window ?? (event.windowNumber > 0 ? NSApp.window(withWindowNumber: event.windowNumber) : nil)
            guard let self,
                  eventWindow == nil || eventWindow === self.window,
                  let editor = self.currentEditor() as? NSTextView,
                  self.window?.firstResponder === editor else { return event }
            if bmuxFindEventIsPlainEscape(event), !editor.hasMarkedText(), self.bmuxOnEscape?(editor) == true { return nil }
            DispatchQueue.main.async { [weak self, weak editor] in
                guard let self, let editor else { return }
                _ = self.bmuxRememberSelection(from: editor)
            }
            return event
        }
    }

    private func bmuxRemoveKeyMonitor() {
        if let bmuxKeyMonitor {
            NSEvent.removeMonitor(bmuxKeyMonitor)
            self.bmuxKeyMonitor = nil
        }
    }

    private func bmuxRestoreRememberedSelection() {
        guard let rememberedSelection = bmuxStoredFindSelection(for: bmuxSelectionOwner) ?? bmuxLastSelectedRange else { return }
        if let editor = currentEditor() as? NSTextView, !editor.hasMarkedText() {
            let selection = bmuxRememberSelection(rememberedSelection, in: editor.string)
            editor.setSelectedRange(selection)
        }
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let editor = self.currentEditor() as? NSTextView,
                  !editor.hasMarkedText() else { return }
            let selection = self.bmuxRememberSelection(rememberedSelection, in: editor.string)
            editor.setSelectedRange(selection)
        }
    }
}
