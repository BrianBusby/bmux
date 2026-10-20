import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

@Suite
struct WorkspaceArchiveSDKTests {
    @Test
    func publicClientPersistsAndReadsArchiveWithoutDeletingItOnClientRecreation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pe-workspace-archive-sdk-tests")
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provenance.sqlite")
        let writer = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let record = ProvenanceArchivedWorkspaceRecord(
            id: "stable-roof-inspection", title: "Maple Street Roof Inspection",
            createdAt: nil, closedAt: Date(timeIntervalSince1970: 200),
            lastActivityAt: Date(timeIntervalSince1970: 190),
            displayAtClose: nil, colorHex: nil, coverageCode: nil
        )
        try await writer.recordArchivedWorkspace(record)

        let reader = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        #expect(try await reader.archivedWorkspaces(.init()).records == [record])
        let sessions = try await reader.workspaceSessions(.init(workspaceID: record.id))
        #expect(sessions.sessions.isEmpty)
        #expect(sessions.partialCoverage)
        try await reader.clearArchivedWorkspaces(at: Date(timeIntervalSince1970: 300))
        #expect(try await writer.archivedWorkspaces(.init()).records.isEmpty)
    }
}
