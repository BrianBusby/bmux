import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

@Suite
struct SessionLifecycleSDKTests {
    @Test
    func recordSessionLifecycleRecordsRootSessionWithoutParentTerminology() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)

        let response = await client.recordSessionLifecycle(
            ProvenanceSessionLifecycleRequest(
                phase: .started,
                sessionID: "session-generic-root",
                agentKind: "generic-agent",
                workspaceID: "workspace-1",
                surfaceID: "terminal",
                workingDirectory: "/repos/generic",
                externalIdentityKind: "job",
                externalIdentityValue: "job-1",
                timestamp: timestamp
            )
        )

        #expect(response.accepted)
        #expect(response.sessionID == "session-generic-root")
        #expect(response.relationshipSessionID == nil)
        #expect(response.externalIdentityID != nil)

        let tree = try await client.sessionTree(
            ProvenanceSessionTreeRequest(rootSessionID: "session-generic-root")
        )
        #expect(tree.found)
        #expect(tree.sessions == [
            ProvenanceSessionRecord(
                id: "session-generic-root",
                agentKind: "generic-agent",
                workspaceID: "workspace-1",
                surfaceID: "terminal",
                cwd: "/repos/generic",
                status: "active",
                startedAt: timestamp,
                updatedAt: timestamp
            ),
        ])
        #expect(tree.relationships.isEmpty)
        #expect(tree.externalIdentities.count == 1)
        #expect(tree.externalIdentities.first?.kind == "job")
        #expect(tree.externalIdentities.first?.externalID == "job-1")
    }

    @Test
    func recordSessionLifecycleRecordsParentRelationshipWhenParentIsSupplied() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let parentSession = ProvenanceSessionRecord(
            id: "session-parent",
            agentKind: "generic-agent",
            status: "active",
            startedAt: timestamp,
            updatedAt: timestamp
        )

        _ = try await client.appendEvent(
            ProvenanceAppendEventRequest(
                event: ProvenanceEvent(
                    id: "event-parent-session",
                    eventType: .sessionObserved,
                    timestamp: timestamp,
                    sessionID: parentSession.id,
                    source: .observed,
                    confidence: .high,
                    payload: ProvenanceEventPayload(session: parentSession)
                )
            )
        )
        let response = await client.recordSessionLifecycle(
            ProvenanceSessionLifecycleRequest(
                phase: .started,
                parentSessionID: parentSession.id,
                agentKind: "generic-agent",
                externalIdentityKind: "job",
                externalIdentityValue: "child-job-1",
                timestamp: timestamp.addingTimeInterval(1)
            )
        )

        #expect(response.accepted)
        let childSessionID = try #require(response.sessionID)
        #expect(response.relationshipSessionID == childSessionID)

        let tree = try await client.sessionTree(
            ProvenanceSessionTreeRequest(rootSessionID: parentSession.id)
        )
        #expect(tree.sessions.map(\.id) == [parentSession.id, childSessionID])
        #expect(tree.relationships.map(\.sessionID) == [childSessionID])
        #expect(tree.relationships.first?.parentSessionID == parentSession.id)
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-session-lifecycle-sdk-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
