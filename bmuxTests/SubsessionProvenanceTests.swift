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
        #expect(child.startedAt == Date(timeIntervalSince1970: 120))
        #expect(child.updatedAt == Date(timeIntervalSince1970: 140))
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
        #expect(replayedChild.startedAt == Date(timeIntervalSince1970: 120))
        #expect(replayedChild.updatedAt == Date(timeIntervalSince1970: 140))
        #expect(replayedTree.relationships.map(\.sessionID) == [child.id])
    }

    @Test
    func buildsDeterministicLifecycleEventsForSameInput() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let recorder = WorkProvenanceSubsessionLifecycleRecorder(store: store)
        let change = Self.lifecycleChange(phase: .started)
        let timestamp = Date(timeIntervalSince1970: 120)

        try await store.append(Self.parentSessionEvent())
        let first = try await recorder.event(for: change, timestamp: timestamp)
        let second = try await recorder.event(for: change, timestamp: timestamp)

        #expect(first.id == second.id)
        #expect(first.eventType == .subsessionStarted)
        #expect(first.payload.session?.id == second.payload.session?.id)
        #expect(first.payload.sessionRelationship?.sessionID == second.payload.sessionRelationship?.sessionID)
        #expect(first.payload.externalIdentities.map(\.id) == second.payload.externalIdentities.map(\.id))
        #expect(first.payload.externalIdentities.map(\.externalID) == ["subagent-1"])
    }

    @Test
    func contractRecorderRecordsNormalizedLifecycleRequest() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let recorder: any ProvenanceSubsessionLifecycleRecording = WorkProvenanceSubsessionLifecycleRecorder(
            store: store
        )

        try await store.append(Self.parentSessionEvent())
        let response = await recorder.recordSubsessionLifecycle(Self.lifecycleRequest(
            phase: .started,
            timestamp: Date(timeIntervalSince1970: 120)
        ))

        let tree = try await store.sessionTree(rootSessionID: "codex-parent")
        let child = try #require(tree.sessions.first { $0.id != "codex-parent" })

        #expect(response.schemaVersion == 1)
        #expect(response.accepted)
        #expect(response.errorDescription == nil)
        #expect(response.eventID != nil)
        #expect(response.childSessionID == child.id)
        #expect(response.relationshipSessionID == child.id)
        #expect(response.externalIdentityID != nil)
        #expect(child.agentKind == "codex")
        #expect(child.status == "active")
        #expect(child.startedAt == Date(timeIntervalSince1970: 120))
        #expect(tree.relationships.map(\.parentSessionID) == ["codex-parent"])
        let identities = try await store.externalIdentities(sessionID: child.id)
        #expect(identities.map(\.externalID) == ["subagent-1"])
    }

    @Test
    func contractRecorderUsesStableFallbackForMissingExternalIdentity() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let recorder: any ProvenanceSubsessionLifecycleRecording = WorkProvenanceSubsessionLifecycleRecorder(
            store: store
        )

        try await store.append(Self.parentSessionEvent())
        let request = Self.lifecycleRequest(
            phase: .started,
            externalIdentityValue: "   ",
            timestamp: Date(timeIntervalSince1970: 120)
        )
        let first = try await recorder.subsessionLifecycleEvent(for: request)
        let second = try await recorder.subsessionLifecycleEvent(for: request)
        let response = await recorder.recordSubsessionLifecycle(request)

        let childID = try #require(response.childSessionID)
        let relationship = try #require(try await store.parentSession(for: childID))
        let identity = try #require(try await store.externalIdentities(sessionID: childID).first)

        #expect(first.id == second.id)
        #expect(first.confidence == .low)
        #expect(first.payload.externalIdentities.map(\.kind) == ["unresolved_subsession"])
        #expect(first.payload.externalIdentities.map(\.externalID) == ["codex:codex-parent:default"])
        #expect(response.accepted)
        #expect(relationship.confidence == .low)
        #expect(identity.kind == "unresolved_subsession")
        #expect(identity.externalID == "codex:codex-parent:default")
    }

    @Test
    func recordsO1LifecycleIngestionTraceRows() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let observabilityStore = try ProvenanceObservabilityStore(
            databaseURL: fixture.observabilityDatabaseURL
        )
        let recorder = WorkProvenanceSubsessionLifecycleRecorder(
            store: store,
            observabilityStore: observabilityStore,
            awaitObservabilityWrites: true
        )

        try await store.append(Self.parentSessionEvent())
        await recorder.record(
            Self.lifecycleChange(phase: .started),
            timestamp: Date(timeIntervalSince1970: 120)
        )

        let traces = try await observabilityStore.lifecycleIngestionRuns()
        let trace = try #require(traces.first)
        let tree = try await store.sessionTree(rootSessionID: "codex-parent")
        let child = try #require(tree.sessions.first { $0.id != "codex-parent" })

        #expect(trace.run.pipelineKind == "lifecycle_ingestion")
        #expect(trace.run.triggerSource == "AgentSubsessionLifecycleChange")
        #expect(trace.run.status == "succeeded")
        #expect(trace.run.parentSessionID == "codex-parent")
        #expect(trace.run.childSessionID == child.id)
        #expect(trace.run.lifecycleEventID != nil)
        #expect(trace.run.relationshipSessionID == child.id)
        #expect(trace.run.externalIdentityID != nil)
        #expect(trace.run.errorCount == 0)
        #expect(trace.stages.map(\.stageName) == [
            "lifecycle_change_received",
            "work_provenance_event_append",
            "work_provenance_projection_update",
        ])
        #expect(trace.stages.allSatisfy { $0.status == "succeeded" })
        #expect(trace.stages.map(\.stageVersion) == ["o1", "o1", "o3"])
        #expect(trace.stages.map(\.errorCount) == [0, 0, 0])
    }

    @Test
    func recordsO3LifecycleProjectionLineageTrace() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let observabilityStore = try ProvenanceObservabilityStore(
            databaseURL: fixture.observabilityDatabaseURL
        )
        let recorder = WorkProvenanceSubsessionLifecycleRecorder(
            store: store,
            observabilityStore: observabilityStore,
            awaitObservabilityWrites: true
        )

        try await store.append(Self.parentSessionEvent())
        await recorder.record(
            Self.lifecycleChange(phase: .started),
            timestamp: Date(timeIntervalSince1970: 120)
        )

        let trace = try #require(try await observabilityStore.lifecycleIngestionRuns().first)
        let childSessionID = try #require(trace.run.childSessionID)
        let lifecycleEventID = try #require(trace.run.lifecycleEventID)
        let lineage = trace.projectionLineage

        #expect(lineage.map(\.pipelineRunID).allSatisfy { $0 == trace.run.pipelineRunID })
        #expect(lineage.map(\.stageName).allSatisfy { $0 == "work_provenance_projection_update" })
        #expect(lineage.map(\.projectionKind).allSatisfy { $0 == "lifecycle_ingestion_projection" })
        #expect(lineage.map(\.sourceEventID).allSatisfy { $0 == lifecycleEventID })
        #expect(lineage.map(\.sourceEventType).allSatisfy { $0 == "subsession_started" })
        #expect(lineage.map(\.sourceSchemaVersion).allSatisfy { $0 == 1 })
        #expect(lineage.map(\.sourcePayloadHash).allSatisfy { $0.hasPrefix("payload-") })
        #expect(lineage.map(\.sourcePayloadHash).allSatisfy { !$0.contains("subagent-1") })
        #expect(lineage.map(\.targetEntityKind) == [
            "session",
            "session_relationship",
            "session_external_identity",
        ])
        #expect(lineage.map(\.targetEntityID).contains(childSessionID))
        #expect(lineage.map(\.operation).allSatisfy { $0 == "upsert" })
        #expect(lineage.map(\.generatorVersion).allSatisfy { $0 == "o3" })
        #expect(lineage.map(\.confidence).allSatisfy { $0 == "high" })
    }

    @Test
    func recordsO2NativeLifecycleIdentityResolutionTrace() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let observabilityStore = try ProvenanceObservabilityStore(
            databaseURL: fixture.observabilityDatabaseURL
        )
        let recorder = WorkProvenanceSubsessionLifecycleRecorder(
            store: store,
            observabilityStore: observabilityStore,
            awaitObservabilityWrites: true
        )

        try await store.append(Self.parentSessionEvent())
        await recorder.record(
            Self.lifecycleChange(phase: .started),
            timestamp: Date(timeIntervalSince1970: 120)
        )

        let trace = try #require(try await observabilityStore.lifecycleIngestionRuns().first)
        let identity = try #require(trace.identityResolutions.first)

        #expect(identity.pipelineRunID == trace.run.pipelineRunID)
        #expect(identity.resolverName == "subsession_lifecycle_identity")
        #expect(identity.resolverVersion == "o2")
        #expect(identity.inputPhase == "started")
        #expect(identity.inputAgentKind == "codex")
        #expect(identity.inputParentSessionID == "codex-parent")
        #expect(identity.inputSubsessionIDState == "present")
        #expect(identity.inputWorkspacePresent)
        #expect(identity.inputSurfacePresent)
        #expect(identity.inputWorkingDirectoryPresent)
        #expect(identity.inputDisplayNamePresent)
        #expect(identity.inputIdentityKind == "subsession")
        #expect(identity.inputIdentityValueHash.hasPrefix("identity-input-"))
        #expect(!identity.inputIdentityValueHash.contains("subagent-1"))
        #expect(identity.selectedIdentityKind == "subsession")
        #expect(identity.selectedIdentityValueCategory == "native_subsession_id")
        #expect(identity.candidateCount == 1)
        #expect(identity.selectedChildSessionID == trace.run.childSessionID)
        #expect(identity.selectedLifecycleEventID == trace.run.lifecycleEventID)
        #expect(identity.selectedRelationshipSessionID == trace.run.relationshipSessionID)
        #expect(identity.selectedExternalIdentityID == trace.run.externalIdentityID)
        #expect(identity.confidence == "high")
        #expect(identity.outcome == "resolved")
        #expect(identity.fallbackState == "native")
        #expect(identity.unresolvedReason == nil)
        #expect(identity.conflictReason == nil)
    }

    @Test
    func recordsO2FallbackUnresolvedLifecycleIdentityResolutionTrace() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let observabilityStore = try ProvenanceObservabilityStore(
            databaseURL: fixture.observabilityDatabaseURL
        )
        let recorder = WorkProvenanceSubsessionLifecycleRecorder(
            store: store,
            observabilityStore: observabilityStore,
            awaitObservabilityWrites: true
        )

        try await store.append(Self.parentSessionEvent())
        await recorder.record(
            Self.lifecycleChange(phase: .started, subsessionID: nil),
            timestamp: Date(timeIntervalSince1970: 120)
        )

        let trace = try #require(try await observabilityStore.lifecycleIngestionRuns().first)
        let identity = try #require(trace.identityResolutions.first)

        #expect(identity.pipelineRunID == trace.run.pipelineRunID)
        #expect(identity.inputSubsessionIDState == "missing")
        #expect(identity.inputIdentityKind == "unresolved_subsession")
        #expect(identity.inputIdentityValueHash.hasPrefix("identity-input-"))
        #expect(!identity.inputIdentityValueHash.contains("codex-parent"))
        #expect(identity.selectedIdentityKind == "unresolved_subsession")
        #expect(identity.selectedIdentityValueCategory == "stable_parent_fallback")
        #expect(identity.candidateCount == 0)
        #expect(identity.selectedChildSessionID == trace.run.childSessionID)
        #expect(identity.selectedLifecycleEventID == trace.run.lifecycleEventID)
        #expect(identity.selectedRelationshipSessionID == trace.run.relationshipSessionID)
        #expect(identity.selectedExternalIdentityID == trace.run.externalIdentityID)
        #expect(identity.confidence == "low")
        #expect(identity.outcome == "unresolved")
        #expect(identity.fallbackState == "fallback_unresolved")
        #expect(identity.unresolvedReason == "missing_native_subsession_identifier")
        #expect(identity.conflictReason == nil)
    }

    @Test
    func filtersLifecycleIngestionTraceRowsByRunSessionAndStatus() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let observabilityStore = try ProvenanceObservabilityStore(
            databaseURL: fixture.observabilityDatabaseURL
        )
        let recorder = WorkProvenanceSubsessionLifecycleRecorder(
            store: store,
            observabilityStore: observabilityStore,
            awaitObservabilityWrites: true
        )

        try await store.append(Self.parentSessionEvent())
        await recorder.record(
            Self.lifecycleChange(phase: .started, parentSessionID: "codex-parent"),
            timestamp: Date(timeIntervalSince1970: 120)
        )
        await recorder.record(
            Self.lifecycleChange(
                phase: .started,
                parentSessionID: "other-parent",
                subsessionID: "subagent-2"
            ),
            timestamp: Date(timeIntervalSince1970: 130)
        )
        await recorder.record(
            Self.lifecycleChange(phase: .started, parentSessionID: "codex-parent"),
            timestamp: Date(timeIntervalSince1970: 120)
        )

        let parentRuns = try await observabilityStore.lifecycleIngestionRuns(
            parentSessionID: "codex-parent"
        )
        #expect(parentRuns.count == 2)
        #expect(parentRuns.allSatisfy { $0.run.parentSessionID == "codex-parent" })

        let otherChildID = try #require(
            try await observabilityStore.lifecycleIngestionRuns(parentSessionID: "other-parent")
                .first?.run.childSessionID
        )
        let childRuns = try await observabilityStore.lifecycleIngestionRuns(
            childSessionID: otherChildID
        )
        #expect(childRuns.map(\.run.parentSessionID) == ["other-parent"])

        let failedRuns = try await observabilityStore.lifecycleIngestionRuns(status: "failed")
        #expect(failedRuns.count == 1)
        #expect(failedRuns.first?.run.errorCount == 1)

        let exactRunID = try #require(parentRuns.first?.run.pipelineRunID)
        let exactRuns = try await observabilityStore.lifecycleIngestionRuns(
            pipelineRunID: exactRunID
        )
        #expect(exactRuns.map(\.run.pipelineRunID) == [exactRunID])
    }

    @Test
    func contractTraceQueryReturnsFilteredBoundedLifecycleTelemetry() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let observabilityStore = try ProvenanceObservabilityStore(
            databaseURL: fixture.observabilityDatabaseURL
        )
        let traceQuery: any ProvenanceLifecycleTraceQuerying = observabilityStore
        let recorder = WorkProvenanceSubsessionLifecycleRecorder(
            store: store,
            observabilityStore: observabilityStore,
            awaitObservabilityWrites: true
        )

        try await store.append(Self.parentSessionEvent())
        await recorder.record(
            Self.lifecycleChange(phase: .started, parentSessionID: "codex-parent"),
            timestamp: Date(timeIntervalSince1970: 120)
        )
        await recorder.record(
            Self.lifecycleChange(
                phase: .started,
                parentSessionID: "other-parent",
                subsessionID: "subagent-2"
            ),
            timestamp: Date(timeIntervalSince1970: 130)
        )
        await recorder.record(
            Self.lifecycleChange(phase: .started, parentSessionID: "codex-parent"),
            timestamp: Date(timeIntervalSince1970: 120)
        )

        let parentResponse = try await traceQuery.lifecycleTraces(ProvenanceLifecycleTraceListRequest(
            parentSessionID: "codex-parent"
        ))
        let returnedRunIDs = Set(parentResponse.runs.map(\.pipelineRunID))

        #expect(parentResponse.schemaVersion == 1)
        #expect(parentResponse.found)
        #expect(parentResponse.reason == nil)
        #expect(parentResponse.runs.count == 2)
        #expect(parentResponse.runs.allSatisfy { $0.parentSessionID == "codex-parent" })
        #expect(parentResponse.stages.allSatisfy { returnedRunIDs.contains($0.pipelineRunID) })
        #expect(parentResponse.identityResolutions.allSatisfy { returnedRunIDs.contains($0.pipelineRunID) })
        #expect(parentResponse.projectionLineage.allSatisfy { returnedRunIDs.contains($0.pipelineRunID) })

        let failedResponse = try await traceQuery.lifecycleTraces(ProvenanceLifecycleTraceListRequest(
            status: "failed"
        ))
        #expect(failedResponse.runs.count == 1)
        #expect(failedResponse.runs.first?.errorCount == 1)

        let limitedResponse = try await traceQuery.lifecycleTraces(ProvenanceLifecycleTraceListRequest(
            limit: 1
        ))
        #expect(limitedResponse.runs.count == 1)

        let missingResponse = try await traceQuery.lifecycleTraces(ProvenanceLifecycleTraceListRequest(
            pipelineRunID: "missing-run"
        ))
        #expect(missingResponse.schemaVersion == 1)
        #expect(!missingResponse.found)
        #expect(missingResponse.reason == "no_lifecycle_traces")
        #expect(missingResponse.runs.isEmpty)
        #expect(missingResponse.stages.isEmpty)
        #expect(missingResponse.identityResolutions.isEmpty)
        #expect(missingResponse.projectionLineage.isEmpty)
    }

    @Test
    func recordsFailedLifecycleIngestionTraceWithoutDuplicatingProvenance() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let observabilityStore = try ProvenanceObservabilityStore(
            databaseURL: fixture.observabilityDatabaseURL
        )
        let recorder = WorkProvenanceSubsessionLifecycleRecorder(
            store: store,
            observabilityStore: observabilityStore,
            awaitObservabilityWrites: true
        )
        let change = Self.lifecycleChange(phase: .started)
        let timestamp = Date(timeIntervalSince1970: 120)

        try await store.append(Self.parentSessionEvent())
        await recorder.record(change, timestamp: timestamp)
        await recorder.record(change, timestamp: timestamp)

        let traces = try await observabilityStore.lifecycleIngestionRuns()
        let failedTrace = try #require(traces.first { $0.run.status == "failed" })
        let events = try await store.events()

        #expect(events.map(\.eventType) == [.sessionObserved, .subsessionStarted])
        #expect(failedTrace.projectionLineage.isEmpty)
        #expect(failedTrace.run.errorCount == 1)
        #expect(failedTrace.run.errorSummary != nil)
        #expect(failedTrace.stages.map(\.stageName) == [
            "lifecycle_change_received",
            "work_provenance_event_append",
            "work_provenance_projection_update",
        ])
        #expect(failedTrace.stages[0].status == "succeeded")
        #expect(failedTrace.stages[1].status == "failed")
        #expect(failedTrace.stages[2].status == "failed")
        let identity = try #require(failedTrace.identityResolutions.first)
        #expect(identity.pipelineRunID == failedTrace.run.pipelineRunID)
        #expect(identity.outcome == "resolved")
        #expect(identity.conflictReason != nil)
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

    @Test(arguments: [nil, "", "   "])
    func missingOrBlankSubsessionIdentifierUsesSameStableFallback(subsessionID: String?) async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let recorder = WorkProvenanceSubsessionLifecycleRecorder(store: store)

        try await store.append(Self.parentSessionEvent())
        let event = try await recorder.event(
            for: Self.lifecycleChange(phase: .started, subsessionID: subsessionID),
            timestamp: Date(timeIntervalSince1970: 120)
        )

        #expect(event.confidence == .low)
        #expect(event.payload.sessionRelationship?.confidence == .low)
        #expect(event.payload.externalIdentities.map(\.kind) == ["unresolved_subsession"])
        #expect(event.payload.externalIdentities.map(\.externalID) == ["codex:codex-parent:default"])
    }

    @Test
    func missingParentRelationshipUsesParentAsRootWithDepthOne() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let store = try WorkProvenanceStore(databaseURL: fixture.databaseURL)
        let recorder = WorkProvenanceSubsessionLifecycleRecorder(store: store)

        let event = try await recorder.event(
            for: Self.lifecycleChange(
                phase: .started,
                parentSessionID: "missing-parent",
                subsessionID: "subagent-1"
            ),
            timestamp: Date(timeIntervalSince1970: 120)
        )
        try await store.append(event)

        let childID = try #require(event.payload.session?.id)
        let relationship = try #require(try await store.parentSession(for: childID))

        #expect(relationship.parentSessionID == "missing-parent")
        #expect(relationship.rootSessionID == "missing-parent")
        #expect(relationship.depth == 1)
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

    private static func lifecycleRequest(
        phase: ProvenanceSubsessionLifecyclePhase,
        parentSessionID: String = "codex-parent",
        externalIdentityValue: String? = "subagent-1",
        timestamp: Date
    ) -> ProvenanceSubsessionLifecycleRequest {
        ProvenanceSubsessionLifecycleRequest(
            phase: phase,
            parentSessionID: parentSessionID,
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: "surface-1",
            workingDirectory: "/repo",
            externalIdentityKind: "subsession",
            externalIdentityValue: externalIdentityValue,
            displayName: "Reviewer",
            timestamp: timestamp
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
        let observabilityDatabaseURL: URL

        init() throws {
            directoryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("bmux-work-provenance-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            databaseURL = directoryURL.appendingPathComponent("provenance.sqlite")
            observabilityDatabaseURL = directoryURL.appendingPathComponent("ProvenanceObservability.sqlite")
        }

        func remove() {
            try? FileManager.default.removeItem(at: directoryURL)
        }
    }
}
