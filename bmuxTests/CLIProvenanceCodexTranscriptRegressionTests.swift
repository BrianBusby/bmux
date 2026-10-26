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

}
