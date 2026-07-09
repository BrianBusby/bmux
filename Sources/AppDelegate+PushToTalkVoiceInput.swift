import AppKit

extension AppDelegate {
    @discardableResult
    func beginPushToTalkVoiceInput(event: NSEvent, preferredWindow: NSWindow?) -> Bool {
        pushToTalkVoiceInputController.beginHold(
            event: event,
            preferredWindow: preferredWindow ?? event.window ?? shortcutRoutingActiveWindow
        )
    }

    @discardableResult
    func stopPushToTalkVoiceInputIfMatchingRelease(event: NSEvent) -> Bool {
        pushToTalkVoiceInputController.stopIfMatchingRelease(event: event)
    }

    @discardableResult
    func togglePushToTalkVoiceInput(preferredWindow: NSWindow?) -> Bool {
        pushToTalkVoiceInputController.toggle(preferredWindow: preferredWindow ?? NSApp.keyWindow ?? NSApp.mainWindow)
    }
}
