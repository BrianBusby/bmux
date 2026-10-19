import AppKit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Retains the actual panel save task started by the editor's shortcut callback.
@MainActor
final class FilePreviewSaveTaskCapture: FilePreviewTextEditingPanel {
    let panel: FilePreviewPanel
    private(set) var task: Task<Void, Never>?

    init(panel: FilePreviewPanel) { self.panel = panel }

    var textContent: String { panel.textContent }
    func attachTextView(_ textView: NSTextView) { panel.attachTextView(textView) }
    func retryPendingFocus() { panel.retryPendingFocus() }
    func updateTextContent(_ nextContent: String) { panel.updateTextContent(nextContent) }

    func saveTextContent() -> Task<Void, Never>? {
        task = panel.saveTextContent()
        return task
    }
}
