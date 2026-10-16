import AppKit

/// Records presentation at the native alert boundary without displaying a sheet or modal UI.
@MainActor
final class NotificationSettingsPromptAlertProbe: NSAlert {
    private(set) var beginSheetModalCallCount = 0
    private(set) var runModalCallCount = 0

    override func beginSheetModal(
        for sheetWindow: NSWindow,
        completionHandler handler: ((NSApplication.ModalResponse) -> Void)?
    ) {
        beginSheetModalCallCount += 1
        handler?(.alertSecondButtonReturn)
    }

    override func runModal() -> NSApplication.ModalResponse {
        runModalCallCount += 1
        return .alertSecondButtonReturn
    }
}
