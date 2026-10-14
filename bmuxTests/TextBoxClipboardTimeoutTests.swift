import AppKit
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Exercises the real general-pasteboard transaction only in the isolated app-host test run.
@MainActor
struct TextBoxClipboardTimeoutTests {
#if DEBUG
    @Test func clipboardReadTimeoutRestoresPasteboard() async throws {
        let pasteboard = NSPasteboard.general
        let snapshots = pasteboard.pasteboardItems?.map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        } ?? []
        let previousTimeout = TextBoxSubmit.debugWaitTimeoutSecondsOverride
        defer {
            // Join the existing runner cleanup before restoring every original representation.
            TextBoxSubmit.debugResetForTesting()
            TextBoxSubmit.debugWaitTimeoutSecondsOverride = previousTimeout
            pasteboard.clearContents()
            let items = snapshots.map { representations in
                let item = NSPasteboardItem()
                for (type, data) in representations { item.setData(data, forType: type) }
                return item
            }
            if !items.isEmpty { #expect(pasteboard.writeObjects(items)) }
        }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("textbox-timeout-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer {
            do { try FileManager.default.removeItem(at: directory) }
            catch { Issue.record(error, "Could not remove owned clipboard attachment directory") }
        }
        let imageURL = try makePNG(in: directory)
        let surface = FakeTextBoxSubmitSurface()
        pasteboard.clearContents()
        pasteboard.declareTypes([.string], owner: nil)
        #expect(pasteboard.setString("user clipboard", forType: .string))
        let (completed, completion) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        defer { completion.finish() }
        TextBoxSubmit.debugWaitTimeoutSecondsOverride = 0
        TextBoxSubmit.debugRunDispatchEvents([
            .captureClipboardReadBaseline,
            .pasteFilePath(imageURL.path),
            .waitForClipboardRead,
        ], via: surface) { _ in completion.yield(()); completion.finish() }
        // Dispatch captures its timeout synchronously; never leave the override across suspension.
        TextBoxSubmit.debugWaitTimeoutSecondsOverride = previousTimeout
        #expect(surface.sentKeys == ["paste_from_clipboard"])
        let didComplete = try await waitForCompletion(completed, timeout: .seconds(1))
        #expect(didComplete)
        #expect(pasteboard.string(forType: .string) == "user clipboard")
    }

    private func waitForCompletion(_ completed: AsyncStream<Void>, timeout: Duration) async throws -> Bool {
        try await withThrowingTaskGroup(of: Bool.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in completed { return true }
                return false
            }
            group.addTask {
                // Preserve the original one-second completion bound; cancellation joins the deadline.
                try await ContinuousClock().sleep(for: timeout)
                return false
            }
            return try await group.next() ?? false
        }
    }

    private func makePNG(in directory: URL) throws -> URL {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1, height: 1)).fill()
        image.unlockFocus()
        let tiff = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: tiff))
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        let url = directory.appendingPathComponent("moon.png")
        try data.write(to: url)
        return url.standardizedFileURL
    }
#endif
}
