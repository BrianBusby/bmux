import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

extension CLIProvenanceCodexTranscriptImporterTests {
    @Test
    func liveImportReadsOnlyOneBoundedChunkPerCall() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let transcriptURL = fixture.directoryURL.appendingPathComponent("large-codex-session.jsonl")
        let metadata = try Self.codexTranscriptFixtureLines()[0]
        let ignoredLine = "{\"type\":\"unsupported\",\"payload\":{}}\n"
        try (metadata + "\n" + String(repeating: ignoredLine, count: 5_000))
            .write(to: transcriptURL, atomically: true, encoding: .utf8)

        var state = CLIProvenanceCodexTranscriptImporter.LiveImportState()
        let importer = CLIProvenanceCodexTranscriptImporter(client: client)
        _ = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)

        #expect(state.offset > 0)
        #expect(state.offset <= 64 * 1_024)
        #expect(state.offset < UInt64(try Data(contentsOf: transcriptURL).count))
    }

    @Test
    func liveImportSkipsMalformedLineAndContinuesWithLaterEvidence() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let transcriptURL = fixture.directoryURL.appendingPathComponent("codex-session.jsonl")
        let lines = try Self.codexTranscriptFixtureLines()
        try (lines[0] + "\nnot-json\n" + lines[1...].joined(separator: "\n") + "\n")
            .write(to: transcriptURL, atomically: true, encoding: .utf8)

        var state = CLIProvenanceCodexTranscriptImporter.LiveImportState()
        let importer = CLIProvenanceCodexTranscriptImporter(client: client)
        _ = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)

        let projection = try await Self.factualProjection(client: client, sessionID: "codex-session-1")
        #expect(projection.latestTurn != nil)
        #expect(state.offset == UInt64(try Data(contentsOf: transcriptURL).count))
    }

    @Test
    func liveImportDetectsSameSizeTranscriptReplacement() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let transcriptURL = fixture.directoryURL.appendingPathComponent("codex-session.jsonl")
        let first = try Self.codexTranscriptFixtureLines().joined(separator: "\n") + "\n"
        try first.write(to: transcriptURL, atomically: true, encoding: .utf8)

        var state = CLIProvenanceCodexTranscriptImporter.LiveImportState()
        let importer = CLIProvenanceCodexTranscriptImporter(client: client)
        _ = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
        #expect(state.metadata?.sessionID == "codex-session-1")

        let replacement = first.replacingOccurrences(of: "codex-session-1", with: "codex-session-2")
        #expect(replacement.utf8.count == first.utf8.count)
        try replacement.write(to: transcriptURL, atomically: true, encoding: .utf8)
        _ = try await importer.importLiveTranscriptAppend(at: transcriptURL, state: &state)
        #expect(state.metadata?.sessionID == "codex-session-2")
    }

    @Test
    func cursorResumesAfterRestartAndHistoricalImportRemainsIdempotent() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let transcriptURL = fixture.directoryURL.appendingPathComponent("session.jsonl")
        let cursorStore = CLIProvenanceCodexTranscriptCursorStore(
            directoryURL: fixture.directoryURL.appendingPathComponent("cursors")
        )
        let lines = try Self.codexTranscriptFixtureLines()
        try (lines[0...2].joined(separator: "\n") + "\n")
            .write(to: transcriptURL, atomically: true, encoding: .utf8)
        let first = CLIProvenanceCodexTranscriptTailer(
            providerSessionID: "codex-session-1", workspaceID: "workspace-1",
            surfaceID: "surface-1", client: client, cursorStore: cursorStore
        )
        let firstOutcome = try await first.consume(at: transcriptURL)
        #expect(firstOutcome.cursorPersisted)
        let firstCursor = try #require(await cursorStore.load(providerSessionID: "codex-session-1"))
        #expect(firstCursor.byteOffset == firstOutcome.offset)
        let firstStatus = try #require(await cursorStore.loadStatus(providerSessionID: "codex-session-1"))
        #expect(firstStatus.cursorOffset == firstCursor.byteOffset)
        #expect(firstStatus.unreadBytes == 0)

        try Self.appendText(lines[3...].joined(separator: "\n") + "\n", to: transcriptURL)
        let restarted = CLIProvenanceCodexTranscriptTailer(
            providerSessionID: "codex-session-1", workspaceID: "workspace-1",
            surfaceID: "surface-1", client: client, cursorStore: cursorStore
        )
        let secondOutcome = try await restarted.consume(at: transcriptURL)
        #expect(secondOutcome.importResult.fileReport.eventsAppended == 4)
        #expect(secondOutcome.importResult.fileReport.duplicateEvents == 0)
        let secondCursor = try #require(await cursorStore.load(providerSessionID: "codex-session-1"))
        #expect(secondCursor.byteOffset > firstCursor.byteOffset)
        #expect(try await CLIProvenanceCodexTranscriptImporter(client: client)
            .importTranscripts(path: transcriptURL.path).eventsAppended == 0)
    }

    @Test
    func partialLineAndFailedAppendDoNotAdvanceCursor() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let transcriptURL = fixture.directoryURL.appendingPathComponent("session.jsonl")
        let cursorStore = CLIProvenanceCodexTranscriptCursorStore(
            directoryURL: fixture.directoryURL.appendingPathComponent("cursors")
        )
        let lines = try Self.codexTranscriptFixtureLines()
        try (lines[0] + "\n" + lines[1])
            .write(to: transcriptURL, atomically: true, encoding: .utf8)
        let tailer = CLIProvenanceCodexTranscriptTailer(
            providerSessionID: "codex-session-1", workspaceID: nil,
            surfaceID: nil, client: client, cursorStore: cursorStore
        )
        let partial = try await tailer.consume(at: transcriptURL)
        let cursor = try #require(await cursorStore.load(providerSessionID: "codex-session-1"))
        #expect(partial.importResult.retainedPartialLine)
        #expect(cursor.byteOffset < partial.offset)

        let failed = CLIProvenanceCodexTranscriptTailer(
            providerSessionID: "codex-session-1", workspaceID: nil,
            surfaceID: nil, client: FailingAppendClient(), cursorStore: cursorStore
        )
        try Self.appendText("\n" + lines[2] + "\n", to: transcriptURL)
        await #expect(throws: (any Error).self) { _ = try await failed.consume(at: transcriptURL) }
        await failed.recordFailure(kind: "append")
        let afterFailure = try #require(await cursorStore.load(providerSessionID: "codex-session-1"))
        #expect(afterFailure.byteOffset == cursor.byteOffset)
        let failedStatus = try #require(await cursorStore.loadStatus(providerSessionID: "codex-session-1"))
        #expect(failedStatus.retrying)
        #expect(failedStatus.appendFailures == 1)

        let recovered = CLIProvenanceCodexTranscriptTailer(
            providerSessionID: "codex-session-1", workspaceID: nil,
            surfaceID: nil, client: client, cursorStore: cursorStore
        )
        let recovery = try await recovered.consume(at: transcriptURL)
        #expect(recovery.importResult.fileReport.prompts == 1)
        #expect(recovery.importResult.fileReport.turns == 1)
    }

    @Test
    func wrongProviderSessionCannotClaimTranscript() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let transcriptURL = fixture.directoryURL.appendingPathComponent("session.jsonl")
        try (Self.codexTranscriptFixtureLines()[0] + "\n")
            .write(to: transcriptURL, atomically: true, encoding: .utf8)
        let cursorStore = CLIProvenanceCodexTranscriptCursorStore(
            directoryURL: fixture.directoryURL.appendingPathComponent("cursors")
        )
        let tailer = CLIProvenanceCodexTranscriptTailer(
            providerSessionID: "different-session", workspaceID: nil,
            surfaceID: nil, client: client, cursorStore: cursorStore
        )
        await #expect(throws: (any Error).self) { _ = try await tailer.consume(at: transcriptURL) }
        #expect(try await cursorStore.load(providerSessionID: "different-session") == nil)
    }

    @Test
    func truncationResetsPersistedCursorEvenWhenInodeIsUnchanged() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let transcriptURL = fixture.directoryURL.appendingPathComponent("session.jsonl")
        let lines = try Self.codexTranscriptFixtureLines()
        try (lines.joined(separator: "\n") + "\n")
            .write(to: transcriptURL, atomically: true, encoding: .utf8)
        let store = CLIProvenanceCodexTranscriptCursorStore(
            directoryURL: fixture.directoryURL.appendingPathComponent("cursors")
        )
        let tailer = CLIProvenanceCodexTranscriptTailer(
            providerSessionID: "codex-session-1", workspaceID: nil,
            surfaceID: nil, client: client, cursorStore: store
        )
        let first = try await tailer.consume(at: transcriptURL)
        #expect(first.cursorPersisted)
        let handle = try FileHandle(forWritingTo: transcriptURL)
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data((lines[0] + "\n").utf8))
        try handle.close()
        let truncated = try await tailer.consume(at: transcriptURL)
        let cursor = try #require(await store.load(providerSessionID: "codex-session-1"))
        #expect(truncated.cursorPersisted)
        #expect(cursor.byteOffset < first.offset)
        #expect(cursor.byteOffset == truncated.offset)
    }

    @Test
    func backlogAgeSurvivesCursorProgressWhileBytesRemainUnread() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let transcriptURL = fixture.directoryURL.appendingPathComponent("session.jsonl")
        let metadata = try Self.codexTranscriptFixtureLines()[0]
        let ignoredLine = "{\"type\":\"unsupported\",\"payload\":{}}\n"
        try (metadata + "\n" + String(repeating: ignoredLine, count: 5_000))
            .write(to: transcriptURL, atomically: true, encoding: .utf8)
        let cursorStore = CLIProvenanceCodexTranscriptCursorStore(
            directoryURL: fixture.directoryURL.appendingPathComponent("cursors")
        )
        let tailer = CLIProvenanceCodexTranscriptTailer(
            providerSessionID: "codex-session-1", workspaceID: nil,
            surfaceID: nil, client: client, cursorStore: cursorStore
        )

        let first = try await tailer.consume(at: transcriptURL)
        let firstStatus = try #require(await cursorStore.loadStatus(providerSessionID: "codex-session-1"))
        let firstBacklogAt = try #require(firstStatus.firstBacklogAt)
        #expect(first.cursorPersisted)
        #expect(first.unreadBytes > 0)

        let second = try await tailer.consume(at: transcriptURL)
        let secondStatus = try #require(await cursorStore.loadStatus(providerSessionID: "codex-session-1"))
        #expect(second.cursorPersisted)
        #expect(second.unreadBytes > 0)
        #expect(secondStatus.firstBacklogAt == firstBacklogAt)
    }


    @Test
    func largeLiveTranscriptSkipsOversizedAndMalformedLinesAndResumes() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let transcriptURL = fixture.directoryURL.appendingPathComponent("large-session.jsonl")
        let cursorStore = CLIProvenanceCodexTranscriptCursorStore(
            directoryURL: fixture.directoryURL.appendingPathComponent("cursors")
        )
        let lines = try Self.codexTranscriptFixtureLines()
        let oversized = String(repeating: "x", count: CLIProvenanceCodexTranscriptImporter.liveLineLimit + 1)
        let firstText = lines[0] + "\n" + oversized + "\nnot-json\n" + lines[1] + "\n" + lines[2]
        try firstText.write(to: transcriptURL, atomically: true, encoding: .utf8)
        let tailer = CLIProvenanceCodexTranscriptTailer(
            providerSessionID: "codex-session-1", workspaceID: nil,
            surfaceID: nil, client: client, cursorStore: cursorStore
        )
        var skipped = 0
        var last: CLIProvenanceCodexTranscriptTailer.Outcome?
        for _ in 0..<100 {
            let outcome = try await tailer.consume(at: transcriptURL)
            skipped += outcome.importResult.skippedLines
            last = outcome
            if !outcome.importResult.hasMoreData { break }
        }
        let first = try #require(last)
        #expect(!first.importResult.hasMoreData)
        #expect(first.importResult.retainedPartialLine)
        #expect(skipped == 2)
        let cursor = try #require(await cursorStore.load(providerSessionID: "codex-session-1"))
        #expect(cursor.lineNumber == 4)
        #expect(cursor.byteOffset == UInt64((lines[0] + "\n" + oversized + "\nnot-json\n" + lines[1] + "\n").utf8.count))
        #expect(cursor.byteOffset < first.offset)

        try Self.appendText("\n", to: transcriptURL)
        let restarted = CLIProvenanceCodexTranscriptTailer(
            providerSessionID: "codex-session-1", workspaceID: nil,
            surfaceID: nil, client: client, cursorStore: cursorStore
        )
        let recovered = try await restarted.consume(at: transcriptURL)
        #expect(recovered.importResult.fileReport.prompts == 1)
        let finalCursor = try #require(await cursorStore.load(providerSessionID: "codex-session-1"))
        #expect(finalCursor.lineNumber == 5)
        #expect(finalCursor.byteOffset == UInt64(firstText.utf8.count + 1))
        #expect(try await CLIProvenanceCodexTranscriptImporter(client: client)
            .importTranscripts(path: transcriptURL.path).eventsAppended == 0)
    }

    @Test
    func largeStreamCrossesChunkBoundaryAndResumesIncompleteRecord() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let transcriptURL = fixture.directoryURL.appendingPathComponent("large-stream.jsonl")
        let cursorStore = CLIProvenanceCodexTranscriptCursorStore(
            directoryURL: fixture.directoryURL.appendingPathComponent("cursors")
        )
        let lines = try Self.codexTranscriptFixtureLines()
        let chunkSize = 64 * 1_024
        let boundary = 82 * chunkSize
        let ignored = "{\"type\":\"unsupported\",\"payload\":{\"padding\":\"" +
            String(repeating: "x", count: 4_000) + "\"}}\n"
        var text = lines[0] + "\n"
        while text.utf8.count + ignored.utf8.count < boundary - 32 { text += ignored }
        let padding = boundary - 10 - text.utf8.count
        #expect(padding > 0)
        text += String(repeating: " ", count: padding - 1) + "\n"
        #expect(text.utf8.count == boundary - 10)
        #expect(lines[1].utf8.count > 10)
        text += lines[1] + "\n" + lines[2]
        #expect(text.utf8.count > 5 * 1_024 * 1_024)
        try text.write(to: transcriptURL, atomically: true, encoding: .utf8)

        let tailer = CLIProvenanceCodexTranscriptTailer(
            providerSessionID: "codex-session-1", workspaceID: nil,
            surfaceID: nil, client: client, cursorStore: cursorStore
        )
        var last: CLIProvenanceCodexTranscriptTailer.Outcome?
        for _ in 0..<100 {
            let outcome = try await tailer.consume(at: transcriptURL)
            last = outcome
            if !outcome.importResult.hasMoreData { break }
        }
        let partial = try #require(last)
        #expect(!partial.importResult.hasMoreData)
        #expect(partial.importResult.retainedPartialLine)
        let cursor = try #require(await cursorStore.load(providerSessionID: "codex-session-1"))
        #expect(cursor.byteOffset == UInt64(text.utf8.count - lines[2].utf8.count))
        let before = try await Self.factualProjection(client: client, sessionID: "codex-session-1")
        #expect(before.latestTurn == nil)

        try Self.appendText("\n", to: transcriptURL)
        let restarted = CLIProvenanceCodexTranscriptTailer(
            providerSessionID: "codex-session-1", workspaceID: nil,
            surfaceID: nil, client: client, cursorStore: cursorStore
        )
        let resumed = try await restarted.consume(at: transcriptURL)
        #expect(resumed.importResult.fileReport.turns == 1)
        #expect(resumed.importResult.fileReport.prompts == 1)
        let projection = try await Self.factualProjection(client: client, sessionID: "codex-session-1")
        #expect(projection.latestTurn?.turn.providerTurnID == "turn-1")
        #expect(projection.latestTurn?.submittedPrompt?.text == "Please add transcript ingestion.")
        #expect(try await CLIProvenanceCodexTranscriptImporter(client: client)
            .importTranscripts(path: transcriptURL.path).eventsAppended == 0)
        let retry = try await restarted.consume(at: transcriptURL)
        #expect(retry.importResult.fileReport.eventsAppended == 0)

        let foreign = (lines[0...2].joined(separator: "\n") + "\n")
            .replacingOccurrences(of: "codex-session-1", with: "codex-session-2")
        let savedCursor = try #require(await cursorStore.load(providerSessionID: "codex-session-1"))
        try foreign.write(to: transcriptURL, atomically: true, encoding: .utf8)
        await #expect(throws: (any Error).self) { _ = try await restarted.consume(at: transcriptURL) }
        let cursorAfterReplacement = try #require(await cursorStore.load(providerSessionID: "codex-session-1"))
        #expect(cursorAfterReplacement.byteOffset == savedCursor.byteOffset)
        let after = try await Self.factualProjection(client: client, sessionID: "codex-session-1")
        #expect(after.latestTurn?.submittedPrompt?.text == projection.latestTurn?.submittedPrompt?.text)
    }

}
