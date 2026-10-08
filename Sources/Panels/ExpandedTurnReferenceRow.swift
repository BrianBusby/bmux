import AppKit
import SwiftUI

struct ExpandedTurnReferenceRow: View {
    let label: String
    let value: String
    var copiedDuration: Duration = .seconds(2)
    @State private var copyGeneration: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            ExpandedTurnEvidenceText(text: value, monospaced: true)
            Button(copyGeneration == nil
                   ? String(localized: "agentSession.expanded.copy", defaultValue: "Copy")
                   : String(localized: "agentSession.expanded.copied", defaultValue: "Copied")) {
                guard WorkspaceSurfaceIdentifierClipboardText.copy(value) else { NSSound.beep(); return }
                copyGeneration = UUID()
                if let window = NSApp.keyWindow {
                    NSAccessibility.post(element: window, notification: .announcementRequested, userInfo: [
                        .announcement: String.localizedStringWithFormat(String(localized: "agentSession.expanded.copiedLabel", defaultValue: "Copied %@"), label),
                        .priority: NSAccessibilityPriorityLevel.medium.rawValue
                    ])
                }
            }
            .accessibilityLabel(String.localizedStringWithFormat(String(localized: "agentSession.expanded.copyLabel", defaultValue: "Copy %@"), label))
            .accessibilityValue(copyGeneration == nil ? "" : String(localized: "agentSession.expanded.copied", defaultValue: "Copied"))
        }
        .task(id: copyGeneration) {
            guard let generation = copyGeneration else { return }
            do {
                // Intentional bounded feedback duration, injected and cancelled on disappearance/re-copy.
                try await ContinuousClock().sleep(for: copiedDuration)
                guard !Task.isCancelled, copyGeneration == generation else { return }
                copyGeneration = nil
            } catch is CancellationError { /* SwiftUI cancels feedback when this row disappears. */ }
            catch { copyGeneration = nil }
        }
        .onChange(of: value) { _, _ in copyGeneration = nil }
        .onDisappear { copyGeneration = nil }
    }
}
