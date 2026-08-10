import BmuxTerminal

extension TerminalPanel {
    @discardableResult
    func sendSocketInputForAction(_ text: String, refreshReason: String) -> TerminalSurface.InputSendResult {
        let result = sendInputResult(text)
        if result == .sent {
            surface.forceRefresh(reason: refreshReason)
        }
        return result
    }

    @discardableResult
    func sendSocketNamedKeyForAction(_ keyName: String, refreshReason: String) -> TerminalSurface.NamedKeySendResult {
        let result = sendNamedKeyResult(keyName)
        if result == .sent {
            surface.forceRefresh(reason: refreshReason)
        }
        return result
    }
}
