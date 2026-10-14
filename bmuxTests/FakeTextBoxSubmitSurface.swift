import AppKit
import BmuxTerminal
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
final class FakeTextBoxSubmitSurface: TextBoxSubmitSurfaceControlling {
    var clipboardReadGeneration = 0
    var textBoxSubmitObservationWindow: NSWindow?
    var textBoxSubmitTerminalSurface: TerminalSurface? { nil }
    var visibleTextValue: String?
    var sendKeyTextResult = true
    var sendTextResult = true
    var sendNamedKeyResult: TerminalSurface.NamedKeySendResult = .sent
    var performBindingActionResult = true
    private(set) var sentText: [String] = []
    private(set) var sentKeys: [String] = []
    func visibleText() -> String? {
        visibleTextValue
    }
    @discardableResult
    func sendKeyText(_ text: String) -> Bool {
        sentText.append(text)
        return sendKeyTextResult
    }
    @discardableResult
    func sendText(_ text: String) -> Bool {
        sentText.append(text)
        return sendTextResult
    }
    @discardableResult
    func sendNamedKey(_ keyName: String) -> TerminalSurface.NamedKeySendResult {
        sentKeys.append(keyName)
        return sendNamedKeyResult
    }
    @discardableResult
    func performBindingAction(_ action: String) -> Bool {
        sentKeys.append(action)
        return performBindingActionResult
    }
    func completeClipboardRead() {
        clipboardReadGeneration += 1
        NotificationCenter.default.post(
            name: .terminalSurfaceDidCompleteClipboardRead,
            object: self
        )
    }
}
