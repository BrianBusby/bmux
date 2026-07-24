import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

#if canImport(bmux_DEV)
private typealias TestBmuxLegacyProvenanceClient = bmux_DEV.BmuxLegacyProvenanceClient
#elseif canImport(bmux)
private typealias TestBmuxLegacyProvenanceClient = bmux.BmuxLegacyProvenanceClient
#endif

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct WorkProvenanceStoreTests {
    @Test
    func appendReplayAndProjectsFileChanges() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)

        try await store.append(Self.attributedEvent())
        try await store.append(Self.unattributedEvent())
        try await store.rebuildProjections()

        let events = try await store.events()
        let context = try await store.currentContext(repositoryPath: "/repo")
        let attributed = try #require(context.dirtyFiles.first {
            $0.fileChange.path == "Sources/WorkspaceManager.swift"
        })
        let unattributed = try #require(context.dirtyFiles.first {
            $0.fileChange.path == "Sources/Unknown.swift"
        })

        #expect(events.map(\.id) == ["event-1", "event-unattributed"])
        #expect(context.recentCheckpoints.first?.workItem?.title == "Explain dirty files")
        #expect(attributed.contribution?.declaredIntent == "Capture work provenance")
        #expect(attributed.session?.agentKind == "codex")
        #expect(context.recentCheckpoints.first?.checkpoint.diffFingerprint == "diff-1")
        #expect(attributed.fileChange.attributionSource == .observed)
        #expect(unattributed.fileChange.attributionSource == .unattributed)
        #expect(unattributed.fileChange.attributionConfidence == .low)
        #expect(unattributed.contribution == nil)
    }

    @Test
    func reopensExistingStoreWithEventsAndProjectionsReadable() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)

        try await store.append(Self.attributedEvent())
        try await store.append(Self.unattributedEvent())

        let reopened = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let events = try await reopened.events()
        let context = try await reopened.currentContext(repositoryPath: "/repo")

        #expect(events.map(\.id) == ["event-1", "event-unattributed"])
        #expect(context.repository?.path == "/repo")
        #expect(context.worktree?.path == "/repo")
        #expect(context.recentCheckpoints.first?.workItem?.id == "WI-1")

        try await reopened.rebuildProjections()
        let replayed = try await reopened.currentContext(repositoryPath: "/repo")

        #expect(replayed.repository?.path == context.repository?.path)
        #expect(replayed.worktree?.path == context.worktree?.path)
        #expect(replayed.recentCheckpoints.first?.workItem?.id == context.recentCheckpoints.first?.workItem?.id)
    }

    @Test
    func duplicateEventIDRollsBackProjectionChanges() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)

        try await store.append(Self.parentSessionEvent())
        try await store.append(Self.childSubsessionEvent(
            id: "duplicate-child-event",
            status: "active",
            timestamp: 120
        ))

        do {
            try await store.append(Self.childSubsessionEvent(
                id: "duplicate-child-event",
                status: "completed",
                timestamp: 140
            ))
            Issue.record("duplicate append unexpectedly succeeded")
        } catch {
            // Expected: duplicate event IDs are rejected before projection mutation.
        }

        let events = try await store.events()
        let tree = try await store.sessionTree(rootSessionID: "codex-parent")
        let child = try #require(tree.sessions.first { $0.id == "codex-child" })

        #expect(events.map(\.id) == ["parent-session", "duplicate-child-event"])
        #expect(child.status == "active")
        #expect(child.updatedAt == Date(timeIntervalSince1970: 120))

        try await store.rebuildProjections()
        let replayedTree = try await store.sessionTree(rootSessionID: "codex-parent")
        let replayedChild = try #require(replayedTree.sessions.first { $0.id == "codex-child" })
        #expect(replayedChild.status == "active")
        #expect(replayedChild.updatedAt == Date(timeIntervalSince1970: 120))
    }

    @Test
    func projectionFailureAfterEventInsertRollsBackEntireAppend() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)

        try await store.append(Self.parentSessionEvent())
        try await store.append(Self.childSubsessionEvent(
            id: "child-start",
            status: "active",
            timestamp: 120
        ))

        do {
            try await store.append(Self.conflictingExternalIdentityEvent())
            Issue.record("conflicting identity append unexpectedly succeeded")
        } catch {
            // Expected: the projection conflict must roll back the event insert.
        }

        let events = try await store.events()
        let tree = try await store.sessionTree(rootSessionID: "codex-parent")

        #expect(events.map(\.id) == ["parent-session", "child-start"])
        #expect(tree.sessions.map(\.id) == ["codex-parent", "codex-child"])
        #expect(tree.relationships.map(\.sessionID) == ["codex-child"])

        try await store.rebuildProjections()
        let replayedTree = try await store.sessionTree(rootSessionID: "codex-parent")
        #expect(replayedTree.sessions.map(\.id) == ["codex-parent", "codex-child"])
        #expect(replayedTree.relationships.map(\.sessionID) == ["codex-child"])
    }

    @Test
    func replayUsesAppendOrderWhenEventTimestampsAreOutOfOrder() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)

        try await store.append(Self.observedEvent(id: "appended-first", timestamp: 200, fingerprint: "late"))
        try await store.append(Self.observedEvent(id: "appended-second", timestamp: 100, fingerprint: "early"))

        let events = try await store.events()
        let liveContext = try await store.currentContext(repositoryPath: "/repo")
        let liveFile = try #require(liveContext.dirtyFiles.first {
            $0.fileChange.path == "Sources/WorkspaceManager.swift"
        })

        #expect(events.map(\.id) == ["appended-first", "appended-second"])
        #expect(liveFile.changeSet?.diffFingerprint == "early")

        try await store.rebuildProjections()
        let replayedContext = try await store.currentContext(repositoryPath: "/repo")
        let replayedFile = try #require(replayedContext.dirtyFiles.first {
            $0.fileChange.path == "Sources/WorkspaceManager.swift"
        })
        #expect(replayedFile.changeSet?.diffFingerprint == "early")
    }

    @Test
    func preservesUnknownEventTypeNames() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let event = WorkProvenanceEvent(
            id: "future-event",
            eventType: "future_engine_event",
            timestamp: Date(timeIntervalSince1970: 100),
            source: .observed,
            confidence: .low
        )

        try await store.append(event)

        let events = try await store.events()
        #expect(events.map(\.eventType.rawValue) == ["future_engine_event"])
    }

    @Test
    func pruningExpiresObservedEventsButPreservesSemanticEventsAndLatestExplanation() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let policy = WorkProvenanceRetentionPolicy(
            observedEventMaximumAge: 10,
            minimumObservedEventsPerWorktree: 2,
            pruneAfterAppendedEvents: 1000
        )
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL, retentionPolicy: policy)

        try await store.append(Self.semanticEvent(id: "semantic-old", timestamp: 100))
        try await store.append(Self.observedEvent(id: "observed-1", timestamp: 100, fingerprint: "diff-1"))
        try await store.append(Self.observedEvent(id: "observed-2", timestamp: 110, fingerprint: "diff-2"))
        try await store.append(Self.observedEvent(id: "observed-3", timestamp: 120, fingerprint: "diff-3"))
        try await store.append(Self.observedEvent(id: "observed-4", timestamp: 130, fingerprint: "diff-4"))
        try await store.append(Self.observedEvent(id: "observed-5", timestamp: 140, fingerprint: "diff-5"))

        let result = try await store.pruneExpiredObservedHistory(now: Date(timeIntervalSince1970: 200))
        try await store.rebuildProjections()

        let events = try await store.events()
        let context = try await store.currentContext(repositoryPath: "/repo")
        let file = try #require(context.dirtyFiles.first {
            $0.fileChange.path == "Sources/WorkspaceManager.swift"
        })

        #expect(result.eventsDeleted == 3)
        #expect(result.fileChangesDeleted == 0)
        #expect(result.changeSetsDeleted == 4)
        #expect(events.map(\.id) == ["semantic-old", "observed-4", "observed-5"])
        #expect(file.changeSet?.diffFingerprint == "diff-5")
        #expect(file.fileChange.attributionSource == .unattributed)
        #expect(file.fileChange.attributionConfidence == .low)
    }

    @Test
    func appendAutomaticallyPrunesAfterConfiguredEventCount() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let policy = WorkProvenanceRetentionPolicy(
            observedEventMaximumAge: 5,
            minimumObservedEventsPerWorktree: 1,
            pruneAfterAppendedEvents: 2
        )
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL, retentionPolicy: policy)

        try await store.append(Self.observedEvent(id: "observed-1", timestamp: 100, fingerprint: "diff-1"))
        try await store.append(Self.observedEvent(id: "observed-2", timestamp: 110, fingerprint: "diff-2"))

        let events = try await store.events()

        #expect(events.map(\.id) == ["observed-2"])
    }

    @Test
    func decodesStoredPayloadsWithoutSessionRelationshipKeys() throws {
        let data = Data(
            """
            {
              "session": {
                "id": "legacy-session",
                "agentKind": "codex",
                "status": "active",
                "updatedAt": 100
              }
            }
            """.utf8
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let payload = try decoder.decode(WorkProvenanceEventPayload.self, from: data)

        #expect(payload.session?.id == "legacy-session")
        #expect(payload.externalIdentities.isEmpty)
        #expect(payload.fileChanges.isEmpty)
        #expect(payload.sessionRelationship == nil)
    }

    @Test
    func persistsSessionRelationshipsAndExternalIdentitiesAcrossReplay() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)

        try await store.append(Self.parentSessionEvent())
        try await store.append(Self.childSubsessionEvent(id: "child-start-1", status: "active", timestamp: 120))
        try await store.append(Self.childSubsessionEvent(id: "child-start-replay", status: "active", timestamp: 121))
        try await store.append(Self.childSubsessionEvent(id: "child-stop-1", status: "completed", timestamp: 140))

        let parent = try await store.parentSession(for: "codex-child")
        let children = try await store.childSessions(for: "codex-parent")
        let identities = try await store.externalIdentities(sessionID: "codex-child")
        let tree = try await store.sessionTree(rootSessionID: "codex-parent")

        #expect(parent?.parentSessionID == "codex-parent")
        #expect(parent?.rootSessionID == "codex-parent")
        #expect(parent?.depth == 1)
        #expect(parent?.confidence == .high)
        #expect(children.map(\.sessionID) == ["codex-child"])
        #expect(identities.map(\.externalID) == ["subagent-1"])
        #expect(identities.first?.system == "codex")
        #expect(identities.first?.kind == "subsession")
        #expect(tree.sessions.map(\.id) == ["codex-parent", "codex-child"])
        #expect(tree.sessions.last?.status == "completed")
        #expect(tree.relationships.map(\.sessionID) == ["codex-child"])

        try await store.rebuildProjections()

        let replayedChildren = try await store.childSessions(for: "codex-parent")
        let replayedIdentities = try await store.externalIdentities(sessionID: "codex-child")
        let replayedTree = try await store.sessionTree(rootSessionID: "codex-parent")

        #expect(replayedChildren.map(\.sessionID) == ["codex-child"])
        #expect(replayedIdentities.map(\.externalID) == ["subagent-1"])
        #expect(replayedTree.sessions.map(\.id) == ["codex-parent", "codex-child"])
        #expect(replayedTree.sessions.last?.status == "completed")
    }

    @Test
    func contractClientAppendsAndReturnsCurrentContext() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let client: any TestBmuxLegacyProvenanceClient = store

        let append = try await client.appendEvent(ProvenanceAppendEventRequest(event: Self.attributedEvent()))
        let context = try await client.currentContext(ProvenanceCurrentContextRequest(repositoryPath: "/repo"))
        let file = try #require(context.dirtyFiles.first {
            $0.fileChange.path == "Sources/WorkspaceManager.swift"
        })

        #expect(append.schemaVersion == 1)
        #expect(append.eventID == "event-1")
        #expect(append.eventType == "progress_checkpoint")
        #expect(context.schemaVersion == 1)
        #expect(context.found)
        #expect(context.reason == nil)
        #expect(context.recentCheckpoints.first?.workItem?.title == "Explain dirty files")
        #expect(file.contribution?.declaredIntent == "Capture work provenance")
        #expect(file.fileChange.attributionSource == .observed)
    }

    @Test
    func contractClientPreservesDuplicateEventRollback() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let client: any TestBmuxLegacyProvenanceClient = store

        _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: Self.parentSessionEvent()))
        _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: Self.childSubsessionEvent(
            id: "duplicate-child-event",
            status: "active",
            timestamp: 120
        )))

        do {
            _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: Self.childSubsessionEvent(
                id: "duplicate-child-event",
                status: "completed",
                timestamp: 140
            )))
            Issue.record("duplicate append unexpectedly succeeded through contract client")
        } catch {
            // Expected: duplicate event IDs are rejected before projection mutation.
        }

        let response = try await store.sessionTree(rootSessionID: "codex-parent")
        let child = try #require(response.sessions.first { $0.id == "codex-child" })

        #expect(child.status == "active")
        #expect(child.updatedAt == Date(timeIntervalSince1970: 120))

        try await store.rebuildProjections()
        let replayed = try await store.sessionTree(rootSessionID: "codex-parent")
        let replayedChild = try #require(replayed.sessions.first { $0.id == "codex-child" })
        #expect(replayedChild.status == "active")
        #expect(replayedChild.updatedAt == Date(timeIntervalSince1970: 120))
    }

    @Test
    func contractClientReturnsSessionTreeWithExternalIdentities() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let client: any TestBmuxLegacyProvenanceClient = store

        _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: Self.parentSessionEvent()))
        _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: Self.childSubsessionEvent(
            id: "child-start-1",
            status: "active",
            timestamp: 120
        )))
        _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: Self.childSubsessionEvent(
            id: "child-stop-1",
            status: "completed",
            timestamp: 140
        )))

        let response = try await store.sessionTree(rootSessionID: "codex-parent")
        var identities: [WorkProvenanceExternalIdentityRecord] = []
        for session in response.sessions {
            identities.append(contentsOf: try await store.externalIdentities(sessionID: session.id))
        }

        #expect(response.rootSessionID == "codex-parent")
        #expect(response.sessions.map(\.id) == ["codex-parent", "codex-child"])
        #expect(response.sessions.last?.status == "completed")
        #expect(response.relationships.map(\.sessionID) == ["codex-child"])
        #expect(identities.map(\.externalID) == ["subagent-1"])

        try await store.rebuildProjections()
        let replayed = try await store.sessionTree(rootSessionID: "codex-parent")
        var replayedIdentities: [WorkProvenanceExternalIdentityRecord] = []
        for session in replayed.sessions {
            replayedIdentities.append(contentsOf: try await store.externalIdentities(sessionID: session.id))
        }
        #expect(replayed.sessions.map(\.id) == response.sessions.map(\.id))
        #expect(replayed.relationships.map(\.sessionID) == response.relationships.map(\.sessionID))
        #expect(replayedIdentities.map(\.externalID) == identities.map(\.externalID))
    }

    @Test
    func contractClientListsWorktreesWithRepositories() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)

        _ = try await client.appendEvent(ProvenanceEngineContracts.ProvenanceAppendEventRequest(
            event: Self.externalAttributedEvent()
        ))

        let response = try await client.worktrees(ProvenanceWorktreeListRequest())

        #expect(response.schemaVersion == 1)
        #expect(response.status == "ok")
        #expect(response.reason == nil)
        #expect(response.worktrees.map(\.worktree.id) == ["worktree-1"])
        #expect(response.worktrees.first?.worktree.path == "/repo")
        #expect(response.worktrees.first?.repository?.remoteSlug == "manaflow-ai/bmux")
    }

    @Test
    func contractClientReturnsCurrentContext() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let client: any TestBmuxLegacyProvenanceClient = store

        _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: Self.attributedEvent()))
        _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: Self.unattributedEvent()))

        let response = try await client.currentContext(ProvenanceCurrentContextRequest(
            repositoryPath: "/repo"
        ))
        let missing = try await client.currentContext(ProvenanceCurrentContextRequest(
            repositoryPath: "/missing"
        ))

        #expect(response.schemaVersion == 1)
        #expect(response.found)
        #expect(response.reason == nil)
        #expect(response.worktree?.id == "worktree-1")
        #expect(response.repository?.path == "/repo")
        #expect(response.activeSessions.map(\.session.id) == ["session-1"])
        #expect(response.dirtyFiles.map(\.fileChange.path) == [
            "Sources/Unknown.swift",
            "Sources/WorkspaceManager.swift",
        ])
        #expect(response.unattributedChanges.map(\.fileChange.path) == ["Sources/Unknown.swift"])
        #expect(response.recentCheckpoints.map(\.checkpoint.id) == ["checkpoint-1"])
        #expect(response.validationRuns.isEmpty)
        #expect(response.conflicts.isEmpty)
        #expect(!missing.found)
        #expect(missing.reason == "no_worktree")
    }

    private static func attributedEvent() -> WorkProvenanceEvent {
        let now = Date(timeIntervalSince1970: 100)
        let repository = ProvenanceRepositoryRecord(
            id: "repo-1", path: "/repo", commonDirectory: "/repo/.git",
            remoteSlug: "manaflow-ai/bmux", createdAt: now, updatedAt: now
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-1", repositoryID: "repo-1", path: "/repo",
            branch: "feature/provenance", baseCommit: "base", currentHEAD: "head",
            isDirty: true, status: "active", lastReconciledAt: now, updatedAt: now
        )
        let session = WorkProvenanceSessionRecord(
            id: "session-1", agentKind: "codex", workspaceID: "workspace-1",
            surfaceID: "surface-1", worktreeID: "worktree-1", cwd: "/repo",
            status: "active", startedAt: now, updatedAt: now
        )
        let workItem = WorkProvenanceWorkItemRecord(
            id: "WI-1", title: "Explain dirty files", status: "active",
            createdAt: now, updatedAt: now
        )
        let contribution = WorkProvenanceContributionRecord(
            id: "contribution-1", sessionID: "session-1", worktreeID: "worktree-1",
            workItemID: "WI-1", declaredIntent: "Capture work provenance",
            expectedScope: ["Sources/WorkspaceManager.swift"], status: "active",
            startedAt: now, assignmentConfidence: .high, updatedAt: now
        )
        return Self.attributedEvent(
            now: now,
            repository: repository,
            worktree: worktree,
            session: session,
            workItem: workItem,
            contribution: contribution
        )
    }

    private static func externalAttributedEvent() -> ProvenanceEngineContracts.ProvenanceEvent {
        let now = Date(timeIntervalSince1970: 100)
        let repository = ProvenanceRepositoryRecord(
            id: "repo-1",
            path: "/repo",
            commonDirectory: "/repo/.git",
            remoteSlug: "manaflow-ai/bmux",
            createdAt: now,
            updatedAt: now
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-1",
            repositoryID: "repo-1",
            path: "/repo",
            branch: "feature/provenance",
            baseCommit: "base",
            currentHEAD: "head",
            isDirty: true,
            status: "active",
            lastReconciledAt: now,
            updatedAt: now
        )
        return ProvenanceEngineContracts.ProvenanceEvent(
            id: "external-event-1",
            eventType: .worktreeObserved,
            timestamp: now,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            source: .observed,
            confidence: .high,
            payload: ProvenanceEngineContracts.ProvenanceEventPayload(
                repository: repository,
                worktree: worktree
            )
        )
    }

    private static func parentSessionEvent() -> WorkProvenanceEvent {
        let now = Date(timeIntervalSince1970: 100)
        let session = WorkProvenanceSessionRecord(
            id: "codex-parent",
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: "surface-1",
            cwd: "/repo",
            status: "active",
            startedAt: now,
            updatedAt: now
        )
        return WorkProvenanceEvent(
            id: "parent-session",
            eventType: .sessionObserved,
            timestamp: now,
            sessionID: session.id,
            source: .observed,
            confidence: .high,
            payload: WorkProvenanceEventPayload(session: session)
        )
    }

    private static func childSubsessionEvent(
        id: String,
        status: String,
        timestamp: TimeInterval
    ) -> WorkProvenanceEvent {
        let now = Date(timeIntervalSince1970: timestamp)
        let session = WorkProvenanceSessionRecord(
            id: "codex-child",
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: "surface-2",
            cwd: "/repo",
            status: status,
            startedAt: Date(timeIntervalSince1970: 120),
            updatedAt: now
        )
        let relationship = WorkProvenanceSessionRelationshipRecord(
            sessionID: "codex-child",
            parentSessionID: "codex-parent",
            rootSessionID: "codex-parent",
            depth: 1,
            source: .observed,
            confidence: .high,
            createdAt: Date(timeIntervalSince1970: 120),
            updatedAt: now
        )
        let identity = WorkProvenanceExternalIdentityRecord(
            id: "identity-codex-subagent-1",
            sessionID: "codex-child",
            system: "codex",
            kind: "subsession",
            externalID: "subagent-1",
            source: .observed,
            confidence: .high,
            createdAt: Date(timeIntervalSince1970: 120),
            updatedAt: now
        )
        return WorkProvenanceEvent(
            id: id,
            eventType: status == "completed" ? .subsessionStopped : .subsessionStarted,
            timestamp: now,
            sessionID: session.id,
            source: .observed,
            confidence: .high,
            payload: WorkProvenanceEventPayload(
                session: session,
                sessionRelationship: relationship,
                externalIdentities: [identity]
            )
        )
    }

    private static func conflictingExternalIdentityEvent() -> WorkProvenanceEvent {
        let now = Date(timeIntervalSince1970: 130)
        let session = WorkProvenanceSessionRecord(
            id: "codex-conflicting-child",
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: "surface-conflict",
            cwd: "/repo",
            status: "active",
            startedAt: now,
            updatedAt: now
        )
        let relationship = WorkProvenanceSessionRelationshipRecord(
            sessionID: "codex-conflicting-child",
            parentSessionID: "codex-parent",
            rootSessionID: "codex-parent",
            depth: 1,
            source: .observed,
            confidence: .high,
            createdAt: now,
            updatedAt: now
        )
        let identity = WorkProvenanceExternalIdentityRecord(
            id: "identity-codex-subagent-1",
            sessionID: "codex-conflicting-child",
            system: "codex",
            kind: "subsession",
            externalID: "different-subagent",
            source: .observed,
            confidence: .high,
            createdAt: now,
            updatedAt: now
        )
        return WorkProvenanceEvent(
            id: "conflicting-identity-event",
            eventType: .subsessionStarted,
            timestamp: now,
            sessionID: session.id,
            source: .observed,
            confidence: .high,
            payload: WorkProvenanceEventPayload(
                session: session,
                sessionRelationship: relationship,
                externalIdentities: [identity]
            )
        )
    }

    private static func attributedEvent(
        now: Date,
        repository: ProvenanceRepositoryRecord,
        worktree: ProvenanceWorktreeRecord,
        session: WorkProvenanceSessionRecord,
        workItem: WorkProvenanceWorkItemRecord,
        contribution: WorkProvenanceContributionRecord
    ) -> WorkProvenanceEvent {
        let checkpoint = WorkProvenanceCheckpointRecord(
            id: "checkpoint-1", contributionID: "contribution-1", sequence: 1,
            gitHEAD: "head", diffFingerprint: "diff-1", summary: "Recorded first batch",
            status: "in_progress", validationState: "not_run",
            semanticConfidence: .medium, freshness: "fresh", createdAt: now
        )
        let changeSet = WorkProvenanceChangeSetRecord(
            id: "changeset-1", checkpointID: "checkpoint-1",
            contributionID: "contribution-1", worktreeID: "worktree-1",
            summary: "Workspace provenance", diffFingerprint: "diff-1", createdAt: now
        )
        let fileChange = WorkProvenanceFileChangeRecord(
            id: "file-1", changeSetID: "changeset-1", repositoryID: "repo-1",
            worktreeID: "worktree-1", path: "Sources/WorkspaceManager.swift",
            status: "modified", beforeHash: "before", afterHash: "after",
            attributionSource: .observed, attributionConfidence: .high, updatedAt: now
        )
        return WorkProvenanceEvent(
            id: "event-1", eventType: .progressCheckpoint, timestamp: now,
            repositoryID: "repo-1", worktreeID: "worktree-1", sessionID: "session-1",
            contributionID: "contribution-1", source: .observed, confidence: .high,
            payload: WorkProvenanceEventPayload(
                repository: repository, worktree: worktree, session: session,
                workItem: workItem, contribution: contribution, checkpoint: checkpoint,
                changeSet: changeSet, fileChanges: [fileChange]
            )
        )
    }

    private static func unattributedEvent() -> WorkProvenanceEvent {
        let now = Date(timeIntervalSince1970: 200)
        let repository = ProvenanceRepositoryRecord(
            id: "repo-1", path: "/repo", createdAt: now, updatedAt: now
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-1", repositoryID: "repo-1", path: "/repo",
            isDirty: true, status: "active", updatedAt: now
        )
        let changeSet = WorkProvenanceChangeSetRecord(
            id: "changeset-unattributed", worktreeID: "worktree-1",
            summary: "Unattributed file write",
            diffFingerprint: "diff-unattributed", createdAt: now
        )
        let fileChange = WorkProvenanceFileChangeRecord(
            id: "file-unattributed", changeSetID: "changeset-unattributed",
            repositoryID: "repo-1", worktreeID: "worktree-1",
            path: "Sources/Unknown.swift", status: "modified",
            attributionSource: .unattributed, attributionConfidence: .low,
            updatedAt: now
        )
        return WorkProvenanceEvent(
            id: "event-unattributed", eventType: .worktreeObserved,
            timestamp: now, repositoryID: "repo-1", worktreeID: "worktree-1",
            source: .observed, confidence: .low,
            payload: WorkProvenanceEventPayload(
                repository: repository, worktree: worktree,
                changeSet: changeSet, fileChanges: [fileChange]
            )
        )
    }

    private static func semanticEvent(id: String, timestamp: TimeInterval) -> WorkProvenanceEvent {
        WorkProvenanceEvent(
            id: id,
            eventType: .progressCheckpoint,
            timestamp: Date(timeIntervalSince1970: timestamp),
            repositoryID: "repo-1",
            worktreeID: "worktree-1",
            source: .declared,
            confidence: .medium
        )
    }

    private static func observedEvent(
        id: String,
        timestamp: TimeInterval,
        fingerprint: String
    ) -> WorkProvenanceEvent {
        let now = Date(timeIntervalSince1970: timestamp)
        let repository = ProvenanceRepositoryRecord(
            id: "repo-1", path: "/repo", createdAt: now, updatedAt: now
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-1", repositoryID: "repo-1", path: "/repo",
            isDirty: true, status: "active", updatedAt: now
        )
        let changeSet = WorkProvenanceChangeSetRecord(
            id: "changeset-\(fingerprint)", worktreeID: "worktree-1",
            summary: "Observed dirty worktree",
            diffFingerprint: fingerprint,
            createdAt: now
        )
        let fileChange = WorkProvenanceFileChangeRecord(
            id: "file-workspace-manager", changeSetID: changeSet.id,
            repositoryID: "repo-1", worktreeID: "worktree-1",
            path: "Sources/WorkspaceManager.swift", status: "modified",
            attributionSource: .unattributed, attributionConfidence: .low,
            updatedAt: now
        )
        return WorkProvenanceEvent(
            id: id,
            eventType: .worktreeObserved,
            timestamp: now,
            repositoryID: "repo-1",
            worktreeID: "worktree-1",
            source: .observed,
            confidence: .medium,
            payload: WorkProvenanceEventPayload(
                repository: repository,
                worktree: worktree,
                changeSet: changeSet,
                fileChanges: [fileChange]
            )
        )
    }

    private struct StoreFixture {
        let directoryURL: URL
        let databaseURL: URL

        init() throws {
            directoryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("bmux-work-provenance-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            databaseURL = directoryURL.appendingPathComponent("provenance.sqlite")
        }

        func remove() {
            try? FileManager.default.removeItem(at: directoryURL)
        }
    }
}
