import AppKit
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Exercises the real general-pasteboard transaction only in the isolated app-host test run.
@MainActor
@Suite(.serialized)
struct TextBoxClipboardTimeoutTests {
#if DEBUG
    @Test func clipboardReadTimeoutRestoresPasteboard() async throws {
        try await withOwnedPasteboardAttachment { pasteboard, imageURL in
            let previousTimeout = TextBoxSubmit.debugWaitTimeoutSecondsOverride
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
    }

    @Test func queuedRunSurvivesAnotherSurfaceFinishing() async throws {
        try await withOwnedPasteboardAttachment { _, imageURL in
            let activeSurface = FakeTextBoxSubmitSurface()
            let finishingSurface = FakeTextBoxSubmitSurface()
            var completions: [String] = []
            let (finished, finish) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
            let (drained, drain) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
            defer { finish.finish(); drain.finish() }
            let previousTimeout = TextBoxSubmit.debugWaitTimeoutSecondsOverride
            TextBoxSubmit.debugWaitTimeoutSecondsOverride = 10
            TextBoxSubmit.debugRunDispatchEvents([
                .captureClipboardReadBaseline,
                .pasteFilePath(imageURL.path),
                .waitForClipboardRead,
                .pasteText("active-first"),
            ], via: activeSurface) { _ in completions.append("active-first") }
            // The runner captures ten seconds while dispatching; restore before any suspension.
            TextBoxSubmit.debugWaitTimeoutSecondsOverride = previousTimeout
            TextBoxSubmit.debugRunDispatchEvents([.pasteText("active-second")], via: activeSurface) { _ in
                completions.append("active-second")
                drain.yield(()); drain.finish()
            }
            TextBoxSubmit.debugRunDispatchEvents([.pasteText("finishing")], via: finishingSurface) { _ in
                completions.append("finishing")
                finish.yield(()); finish.finish()
            }
            let otherCompleted = try await waitForCompletion(finished, timeout: .seconds(1))
            #expect(otherCompleted)
            #expect(completions == ["finishing"])
            #expect(finishingSurface.sentText == ["finishing"])
            #expect(activeSurface.sentText == [])
            #expect(activeSurface.sentKeys == ["paste_from_clipboard"])

            activeSurface.completeClipboardRead()
            let queueCompleted = try await waitForCompletion(drained, timeout: .seconds(1))
            #expect(queueCompleted)
            #expect(activeSurface.sentText == ["active-first", "active-second"])
            #expect(completions == ["finishing", "active-first", "active-second"])
        }
    }

    /// Owns the general-pasteboard snapshot and attachment for these serialized CI cases.
    private func withOwnedPasteboardAttachment(
        _ operation: @MainActor (NSPasteboard, URL) async throws -> Void
    ) async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("textbox-timeout-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer {
            do { try FileManager.default.removeItem(at: directory) }
            catch { Issue.record(error, "Could not remove owned clipboard attachment directory") }
        }
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
        let imageURL = try makePNG(in: directory)
        try await operation(pasteboard, imageURL)
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
