import Foundation
import ProvenanceEngineContracts
import Testing

@Suite
struct ProvenanceEngineHealthTests {
    @Test
    func healthPayloadRoundTripsThroughJSON() throws {
        let health = ProvenanceEngineHealth(
            status: .available,
            version: "0.1.0",
            capabilities: [
                .appendEvent,
                .querySessionTree,
                .queryCurrentContext,
            ]
        )

        let data = try JSONEncoder().encode(health)
        let decoded = try JSONDecoder().decode(ProvenanceEngineHealth.self, from: data)

        #expect(decoded == health)
        #expect(decoded.schemaVersion == 1)
    }

    @Test
    func capabilityRawValuesAreStableSnakeCaseNames() {
        #expect(ProvenanceEngineCapability.appendEvent.rawValue == "append_event")
        #expect(ProvenanceEngineCapability.recordSubsessionLifecycle.rawValue == "record_subsession_lifecycle")
        #expect(ProvenanceEngineCapability.querySessionTree.rawValue == "query_session_tree")
        #expect(ProvenanceEngineCapability.queryFileExplanation.rawValue == "query_file_explanation")
        #expect(ProvenanceEngineCapability.queryWorktrees.rawValue == "query_worktrees")
        #expect(ProvenanceEngineCapability.queryCurrentContext.rawValue == "query_current_context")
    }

    @Test
    func healthCheckingProtocolSupportsInProcessClients() async throws {
        let client = StaticHealthClient(
            health: ProvenanceEngineHealth(
                status: .degraded,
                version: "0.1.0",
                capabilities: [.queryWorktrees]
            )
        )

        let health = try await client.health()

        #expect(health.status == .degraded)
        #expect(health.capabilities == [.queryWorktrees])
    }

    @Test
    func currentContextRequestDefaultsMatchInitialClientBounds() {
        let request = ProvenanceCurrentContextRequest(repositoryPath: "/repo")

        #expect(request.activeSessionLimit == 10)
        #expect(request.dirtyFileLimit == 25)
        #expect(request.unattributedChangeLimit == 15)
        #expect(request.recentCheckpointLimit == 5)
        #expect(request.validationRunLimit == 5)
        #expect(request.conflictLimit == 10)
    }

    @Test
    func eventPayloadRoundTripsAndPreservesUnknownEventType() throws {
        let event = ProvenanceEvent(
            id: "event-1",
            eventType: ProvenanceEventType(rawValue: "future_event_type"),
            timestamp: Self.timestamp,
            repositoryID: "repo-1",
            worktreeID: "worktree-1",
            sessionID: "session-1",
            source: .observed,
            confidence: .high,
            payload: ProvenanceEventPayload(
                repository: Self.repository,
                worktree: Self.worktree,
                session: Self.session,
                sessionRelationship: Self.relationship,
                externalIdentities: [Self.externalIdentity],
                fileChanges: [Self.fileChange]
            )
        )

        let decoded = try Self.roundTrip(event)

        #expect(decoded == event)
        #expect(decoded.eventType.rawValue == "future_event_type")
        #expect(decoded.payload.externalIdentities == [Self.externalIdentity])
        #expect(decoded.payload.fileChanges == [Self.fileChange])
    }

    @Test
    func olderEventPayloadWithoutArrayFieldsDecodesWithEmptyArrays() throws {
        let json = #"{"repository":{"id":"repo-1","path":"/repo","createdAt":1,"updatedAt":1}}"#
        let data = try #require(json.data(using: .utf8))

        let payload = try JSONDecoder().decode(ProvenanceEventPayload.self, from: data)

        #expect(payload.repository?.id == "repo-1")
        #expect(payload.externalIdentities.isEmpty)
        #expect(payload.fileChanges.isEmpty)
    }

    @Test
    func engineClientProtocolSupportsInProcessImplementations() async throws {
        let client = StaticProvenanceEngineClient()

        let append = try await client.appendEvent(ProvenanceAppendEventRequest(event: Self.event))
        let lifecycle = await client.recordSubsessionLifecycle(Self.lifecycleRequest)
        let tree = try await client.sessionTree(ProvenanceSessionTreeRequest(rootSessionID: "session-1"))
        let context = try await client.currentContext(ProvenanceCurrentContextRequest(repositoryPath: "/repo"))

        #expect(append.eventID == "event-1")
        #expect(lifecycle.accepted)
        #expect(tree.sessions == [Self.session])
        #expect(context.repositoryPath == "/repo")
    }

    fileprivate static let timestamp = Date(timeIntervalSince1970: 1)

    fileprivate static let repository = ProvenanceRepositoryRecord(
        id: "repo-1",
        path: "/repo",
        createdAt: timestamp,
        updatedAt: timestamp
    )

    fileprivate static let worktree = ProvenanceWorktreeRecord(
        id: "worktree-1",
        repositoryID: "repo-1",
        path: "/repo",
        branch: "main",
        isDirty: true,
        status: "active",
        updatedAt: timestamp
    )

    fileprivate static let session = ProvenanceSessionRecord(
        id: "session-1",
        agentKind: "codex",
        worktreeID: "worktree-1",
        status: "active",
        startedAt: timestamp,
        updatedAt: timestamp
    )

    fileprivate static let relationship = ProvenanceSessionRelationshipRecord(
        sessionID: "session-1",
        parentSessionID: "parent-session-1",
        rootSessionID: "parent-session-1",
        depth: 1,
        source: .observed,
        confidence: .high,
        createdAt: timestamp,
        updatedAt: timestamp
    )

    fileprivate static let externalIdentity = ProvenanceExternalIdentityRecord(
        id: "external-identity-1",
        sessionID: "session-1",
        system: "codex",
        kind: "thread",
        externalID: "thread-1",
        source: .observed,
        confidence: .high,
        createdAt: timestamp,
        updatedAt: timestamp
    )

    fileprivate static let fileChange = ProvenanceFileChangeRecord(
        id: "file-change-1",
        changeSetID: "change-set-1",
        repositoryID: "repo-1",
        worktreeID: "worktree-1",
        path: "Sources/App.swift",
        status: "modified",
        attributionSource: .observed,
        attributionConfidence: .high,
        updatedAt: timestamp
    )

    fileprivate static let event = ProvenanceEvent(
        id: "event-1",
        eventType: .progressCheckpoint,
        timestamp: timestamp,
        source: .declared,
        confidence: .medium
    )

    fileprivate static let lifecycleRequest = ProvenanceSubsessionLifecycleRequest(
        phase: .started,
        parentSessionID: "session-1",
        agentKind: "codex",
        timestamp: timestamp
    )

    private static func roundTrip<Value: Codable>(_ value: Value) throws -> Value {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(Value.self, from: data)
    }
}

private struct StaticHealthClient: ProvenanceEngineHealthChecking {
    let health: ProvenanceEngineHealth

    func health() async throws -> ProvenanceEngineHealth {
        health
    }
}

private struct StaticProvenanceEngineClient: ProvenanceEngineClient {
    func health() async throws -> ProvenanceEngineHealth {
        ProvenanceEngineHealth(
            status: .available,
            version: "0.1.0",
            capabilities: [.appendEvent, .recordSubsessionLifecycle, .queryCurrentContext]
        )
    }

    func appendEvent(_ request: ProvenanceAppendEventRequest) async throws -> ProvenanceAppendEventResponse {
        ProvenanceAppendEventResponse(eventID: request.event.id, eventType: request.event.eventType.rawValue)
    }

    func recordSubsessionLifecycle(
        _ request: ProvenanceSubsessionLifecycleRequest
    ) async -> ProvenanceSubsessionLifecycleResponse {
        ProvenanceSubsessionLifecycleResponse(
            accepted: true,
            eventID: "event-1",
            childSessionID: request.parentSessionID,
            relationshipSessionID: request.parentSessionID,
            externalIdentityID: nil
        )
    }

    func sessionTree(_ request: ProvenanceSessionTreeRequest) async throws -> ProvenanceSessionTreeResponse {
        ProvenanceSessionTreeResponse(
            rootSessionID: request.rootSessionID,
            found: true,
            sessions: [ProvenanceEngineHealthTests.session],
            relationships: [ProvenanceEngineHealthTests.relationship],
            externalIdentities: [ProvenanceEngineHealthTests.externalIdentity]
        )
    }

    func fileExplanation(
        _ request: ProvenanceFileExplanationRequest
    ) async throws -> ProvenanceFileExplanationResponse {
        ProvenanceFileExplanationResponse(found: false, reason: "not_implemented", explanation: nil)
    }

    func worktrees(_ request: ProvenanceWorktreeListRequest) async throws -> ProvenanceWorktreeListResponse {
        ProvenanceWorktreeListResponse(worktrees: [])
    }

    func currentContext(
        _ request: ProvenanceCurrentContextRequest
    ) async throws -> ProvenanceCurrentContextResponse {
        ProvenanceCurrentContextResponse(
            found: true,
            repositoryPath: request.repositoryPath,
            worktree: ProvenanceEngineHealthTests.worktree,
            repository: ProvenanceEngineHealthTests.repository,
            activeSessions: [],
            dirtyFiles: [],
            unattributedChanges: [],
            recentCheckpoints: [],
            validationRuns: [],
            conflicts: []
        )
    }
}
