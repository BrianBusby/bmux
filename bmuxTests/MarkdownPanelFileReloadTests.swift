import Combine
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct MarkdownPanelFileReloadTests {
    @Test func openPanelReloadsWhenFileChangesOnDisk() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-markdown-panel-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: directory) }
            catch { Issue.record(error, "Could not remove owned Markdown reload directory") }
        }
        let file = directory.appendingPathComponent("live.md")
        let original = "# Original\n\nBody before save.\n"
        let updated = "# Updated\n\nBody after external save.\n"
        try original.write(to: file, atomically: true, encoding: .utf8)
        let panel = MarkdownPanel(workspaceId: UUID(), filePath: file.path)
        defer { panel.close() }

        #expect(panel.content == original)
        #expect(!panel.isFileUnavailable)
        try await reload(panel, file: file, updated: updated)
        #expect(panel.content == updated)
        #expect(panel.textContent == updated)
        #expect(!panel.isDirty)
    }

    private func reload(_ panel: MarkdownPanel, file: URL, updated: String, timeout: Duration = .seconds(3)) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask { try await observeReload(panel, file: file, updated: updated) }
            group.addTask {
                // Original three-second failure allowance, never a settling or polling delay.
                try await ContinuousClock().sleep(until: deadline)
                throw ReloadFailure.timedOut
            }
            try await group.next()
        }
    }

    private func observeReload(_ panel: MarkdownPanel, file: URL, updated: String) async throws {
        var subscribed = false
        // Bridge the existing legacy publisher through its native AsyncSequence;
        // its initial value proves subscription before the external atomic save.
        for await content in panel.$content.values {
            if !subscribed {
                subscribed = true
                try updated.write(to: file, atomically: true, encoding: .utf8)
            } else if content == updated {
                return
            }
        }
        throw CancellationError()
    }

    private enum ReloadFailure: Error { case timedOut }
}
