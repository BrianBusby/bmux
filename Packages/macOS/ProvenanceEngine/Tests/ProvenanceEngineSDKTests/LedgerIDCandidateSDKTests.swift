import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

@Suite struct LedgerIDCandidateSDKTests {
    @Test func publicFactoryExposesOptInCandidateWithoutChangingV1() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-id-candidate-sdk-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.sqlite")
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let candidate = try #require(client as? any ProvenanceLedgerIDCandidateClient)
        let event = ProvenanceEvent(id: "event", eventType: .sessionObserved, source: .observed, confidence: .high)
        #expect(try await candidate.appendLedgerIDCandidate(.init(event: event)) == .inserted)
        let reopened = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let reopenedCandidate = try #require(reopened as? any ProvenanceLedgerIDCandidateClient)
        #expect(try await reopenedCandidate.appendLedgerIDCandidate(.init(event: event)) == .idAlreadyPresent)
        await #expect(throws: (any Error).self) { try await reopened.appendEvent(.init(event: event)) }
    }
}
