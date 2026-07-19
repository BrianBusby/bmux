import BMUXAgentLaunch
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct SubsessionProvenanceTests {
    @Test
    func recordsSubsessionStartAndStopIntoSessionTree() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let recorder = WorkProvenanceSubsessionLifecycleRecorder(store: store)

        try await store.append(Self.parentSessionEvent())
        await recorder.record(
            Self.lifecycleChange(phase: .started),
            timestamp: Date(timeIntervalSince1970: 120)
        )
        await recorder.record(
            Self.lifecycleChange(phase: .stopped),
            timestamp: Date(timeIntervalSince1970: 140)
        )

        let tree = try await store.sessionTree(rootSessionID: "codex-parent")
        let child = try #require(tree.sessions.first { $0.id != "codex-parent" })
        let relationship = try #require(tree.relationships.first)
        let identities = try await store.externalIdentities(sessionID: child.id)
        let events = try await store.events()

        #expect(child.agentKind == "codex")
        #expect(child.workspaceID == "workspace-1")
        #expect(child.surfaceID == "surface-1")
        #expect(child.cwd == "/repo")
        #expect(child.status == "completed")
        #expect(relationship.parentSessionID == "codex-parent")
        #expect(relationship.rootSessionID == "codex-parent")
        #expect(relationship.depth == 1)
        #expect(relationship.confidence == .high)
        #expect(identities.map(\.externalID) == ["subagent-1"])
        #expect(events.map(\.eventType) == [.sessionObserved, .subsessionStarted, .subsessionStopped])

        try await store.rebuildProjections()

        let replayedTree = try await store.sessionTree(rootSessionID: "codex-parent")
        let replayedChild = try #require(replayedTree.sessions.first { $0.id != "codex-parent" })
        #expect(replayedChild.id == child.id)
        #expect(replayedChild.status == "completed")
        #expect(replayedTree.relationships.map(\.sessionID) == [child.id])
    }

    @Test
    func derivesNestedRootAndDepthFromExistingParentRelationship() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let recorder = WorkProvenanceSubsessionLifecycleRecorder(store: store)

        try await store.append(Self.parentSessionEvent())
        let firstLevel = Self.lifecycleChange(
            phase: .started,
            parentSessionID: "codex-parent",
            subsessionID: "subagent-1"
        )
        let firstLevelEvent = try await recorder.event(
            for: firstLevel,
            timestamp: Date(timeIntervalSince1970: 120)
        )
        try await store.append(firstLevelEvent)
        let firstLevelChildID = try #require(firstLevelEvent.payload.session?.id)
        let nested = Self.lifecycleChange(
            phase: .started,
            parentSessionID: firstLevelChildID,
            subsessionID: "subagent-2"
        )

        await recorder.record(nested, timestamp: Date(timeIntervalSince1970: 130))

        let tree = try await store.sessionTree(rootSessionID: "codex-parent")
        let nestedRelationship = try #require(
            tree.relationships.first { $0.parentSessionID == firstLevelChildID }
        )
        #expect(nestedRelationship.rootSessionID == "codex-parent")
        #expect(nestedRelationship.depth == 2)
    }

    @Test
    func missingSubsessionIdentifierUsesLowConfidenceStableFallback() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let recorder = WorkProvenanceSubsessionLifecycleRecorder(store: store)

        try await store.append(Self.parentSessionEvent())
        let event = try await recorder.event(
            for: Self.lifecycleChange(phase: .started, subsessionID: nil),
            timestamp: Date(timeIntervalSince1970: 120)
        )
        try await store.append(event)

        let childID = try #require(event.payload.session?.id)
        let relationship = try #require(try await store.parentSession(for: childID))
        let identity = try #require(try await store.externalIdentities(sessionID: childID).first)

        #expect(relationship.confidence == .low)
        #expect(identity.kind == "unresolved_subsession")
        #expect(identity.confidence == .low)
        #expect(identity.externalID == "codex:codex-parent:default")
    }

    @Test
    func stopBeforeStartStillCreatesCompletedChildRelationship() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let recorder = WorkProvenanceSubsessionLifecycleRecorder(store: store)

        try await store.append(Self.parentSessionEvent())
        await recorder.record(
            Self.lifecycleChange(phase: .stopped),
            timestamp: Date(timeIntervalSince1970: 140)
        )

        let tree = try await store.sessionTree(rootSessionID: "codex-parent")
        let child = try #require(tree.sessions.first { $0.id != "codex-parent" })
        #expect(child.status == "completed")
        #expect(child.startedAt == nil)
        #expect(tree.relationships.map(\.sessionID) == [child.id])
    }

    private static func lifecycleChange(
        phase: AgentSubsessionLifecycleChange.Phase,
        parentSessionID: String = "codex-parent",
        subsessionID: String? = "subagent-1"
    ) -> AgentSubsessionLifecycleChange {
        AgentSubsessionLifecycleChange(
            phase: phase,
            parentSessionID: parentSessionID,
            agentKind: .codex,
            workspaceID: "workspace-1",
            surfaceID: "surface-1",
            workingDirectory: "/repo",
            subsessionID: subsessionID,
            displayName: "Reviewer"
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
