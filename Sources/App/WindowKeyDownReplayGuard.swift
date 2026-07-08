import AppKit
import BmuxTerminal

extension NSEvent {
    var bmuxIsUndoRedoCommandEquivalent: Bool {
        let normalizedFlags = modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.numericPad, .function, .capsLock])
        return type == .keyDown
            && (normalizedFlags == [.command] || normalizedFlags == [.command, .shift])
            && KeyboardLayout.normalizedCharacters(for: self) == "z"
    }
}

/// Identity of a key event currently being force-dispatched into a responder's
/// `keyDown(with:)` by `NSWindow.bmux_performKeyEquivalent(with:)`.
///
/// Forwarding keyDown can re-enter `performKeyEquivalent` with the same event
/// while the dispatch is still on the stack: WebKit replays unhandled keys
/// through the responder chain, and on macOS 26 `-[NSWindow keyDown:]`
/// re-enters `performKeyEquivalent`. Without a replay guard at the dispatch
/// chokepoint the same event ping-pongs between the swizzle and the focused
/// responder until the main-thread stack overflows
/// (https://github.com/manaflow-ai/bmux/issues/5887).
///
/// Identity is the event's stable field tuple rather than object identity so
/// the guard still holds if AppKit/WebKit re-deliver the event as an equal
/// copy. Key autorepeat produces distinct events (fresh timestamps), so
/// repeat typing is never throttled. The dispatching window's number is part
/// of the identity so windows cannot suppress each other's dispatches.
private struct BmuxForceDispatchedKeyEventIdentity: Hashable {
    let windowNumber: Int
    let eventType: UInt
    let keyCode: UInt16
    let modifierFlags: UInt
    let timestamp: TimeInterval
}

/// Events whose force-dispatch is currently on the main-thread stack.
/// Main-thread only (key-event dispatch); entries are stack-scoped, inserted
/// before `keyDown(with:)` and removed when the dispatch unwinds, so WebKit's
/// legitimate replay of an unhandled key (which arrives after the original
/// dispatch has fully unwound) is still force-dispatched normally.
private var bmuxInFlightForceDispatchedKeyEventIdentities = Set<BmuxForceDispatchedKeyEventIdentity>()

extension NSWindow {
    func bmuxRouteUndoRedoCommandEquivalentAwayFromAppKit(
        _ event: NSEvent,
        terminalView: GhosttyNSView?,
        webView: BmuxWebView?,
        browserWebKitKeyDownReentry: Bool
    ) -> Bool {
        guard event.bmuxIsUndoRedoCommandEquivalent,
              !bmuxFirstResponderPreservesLocalUndoRedo,
              !bmuxIsLikelyWebInspectorResponder(firstResponder) else {
            return false
        }
        if let terminalView {
            if terminalView.performKeyEquivalentAfterMenuMiss(with: event) {
#if DEBUG
                bmuxDebugLog("  -> undo/redo routed to terminal before AppKit menu")
#endif
                return true
            }
            if bmuxForceDispatchKeyDownOnce(event, to: terminalView, reason: "terminal undo/redo") {
#if DEBUG
                bmuxDebugLog("  -> undo/redo keyDown fallback routed to terminal")
#endif
                return true
            }
            return true
        }
        if let webView {
            if browserWebKitKeyDownReentry {
#if DEBUG
                bmuxDebugLog("  -> undo/redo browser reentry suppressed before AppKit menu")
#endif
                return true
            }
            if webView.performKeyEquivalent(with: event) {
#if DEBUG
                bmuxDebugLog("  -> undo/redo routed to browser before AppKit menu")
#endif
                return true
            }
            if bmuxForceDispatchKeyDownOnce(event, to: webView, reason: "browser undo/redo") {
#if DEBUG
                bmuxDebugLog("  -> undo/redo keyDown fallback routed to browser")
#endif
                return true
            }
            // Do not fall through to AppKit Undo from generic browser focus:
            // that is the stale NSUndoManager path this router avoids. Focused
            // editable AppKit responders and Web Inspector are exempted above.
            return true
        }
        return false
    }

    private var bmuxFirstResponderPreservesLocalUndoRedo: Bool {
        guard let responder = firstResponder else { return false }
        if let textView = responder as? NSTextView {
            return textView.isEditable || textView.isFieldEditor
        }
        if let textField = responder as? NSTextField {
            return textField.isEditable
        }
        return false
    }

    /// Single chokepoint for every direct `keyDown(with:)` force-dispatch made
    /// by `bmux_performKeyEquivalent(with:)`.
    ///
    /// Dispatches `event` into `target`'s `keyDown(with:)` unless the same
    /// event is already being force-dispatched lower on this window's call
    /// stack, and returns whether the dispatch happened. Callers that get
    /// `false` back must decline the event (fall through to default AppKit
    /// handling) instead of dispatching themselves; re-dispatching the same
    /// in-flight event is the infinite key-routing loop from
    /// https://github.com/manaflow-ai/bmux/issues/5887.
    func bmuxForceDispatchKeyDownOnce(
        _ event: NSEvent,
        to target: NSResponder,
        reason: @autoclosure () -> String
    ) -> Bool {
        let identity = BmuxForceDispatchedKeyEventIdentity(
            windowNumber: self.windowNumber,
            eventType: event.type.rawValue,
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags.rawValue,
            timestamp: event.timestamp
        )
        guard !bmuxInFlightForceDispatchedKeyEventIdentities.contains(identity) else {
#if DEBUG
            bmuxDebugLog("  → \(reason()) reentry; declining force-dispatch of in-flight key event")
#endif
            return false
        }
        bmuxInFlightForceDispatchedKeyEventIdentities.insert(identity)
        defer { bmuxInFlightForceDispatchedKeyEventIdentities.remove(identity) }
#if DEBUG
        bmuxDebugLog("  → \(reason()) routed to firstResponder.keyDown")
#endif
        target.keyDown(with: event)
        return true
    }
}
