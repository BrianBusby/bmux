#!/bin/bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/../../.." && pwd)"
task_root="$(mktemp -d /tmp/bmux-smart-session-stale.XXXXXXXX)"
trap 'rm -rf "$task_root"' EXIT
mkdir -p "$task_root/package/Sources/Store" "$task_root/package/Tests/StoreTests" "$task_root/home" "$task_root/cache" "$task_root/tmp"
cp "$repo"/Sources/WorkProvenance/AgentSessionSmartSession*.swift "$task_root/package/Sources/Store/"
cat > "$task_root/package/Sources/Store/BreadcrumbStub.swift" <<'SWIFT'
import Foundation
enum StartupBreadcrumbLog {
    static func append(_ name: String, fields: [String: String]) {}
}
SWIFT
python3 - "$repo" "$task_root/package" <<'PY'
import json, pathlib, sys
repo, package = map(pathlib.Path, sys.argv[1:])
(package / 'Package.swift').write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "SmartSessionStaleFixture", platforms: [.macOS(.v13)], dependencies: [.package(path: %s)], targets: [.target(name: "Store", dependencies: [.product(name: "ProvenanceEngineContracts", package: "ProvenanceEngine")]), .testTarget(name: "StoreTests", dependencies: ["Store", .product(name: "ProvenanceEngineContracts", package: "ProvenanceEngine")])])
''' % json.dumps(str(repo / 'Packages/macOS/ProvenanceEngine')))
source = (repo / 'bmuxTests/AgentSessionSmartSessionStoreTests.swift').read_text()
source = source.replace('''#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif''', '@testable import Store')
source = source.replace('''    private let models: [ProvenanceSessionWorkModel]''', '''    private var failWorkModel = false
    private var responseOverride: ProvenanceSessionWorkModelResponse?
    private var secondSessionModel: ProvenanceSessionWorkModel?
    func setSecondSessionModel(_ value: ProvenanceSessionWorkModel) { secondSessionModel = value }
    func setResponse(_ response: ProvenanceSessionWorkModelResponse) { responseOverride = response }
    func failNextReads() { failWorkModel = true }
    func restoreReads() { failWorkModel = false }
    private let models: [ProvenanceSessionWorkModel]''')
source = source.replace('''        let index = workModelRequests.count
        workModelRequests.append(request)''', '''        let index = workModelRequests.count
        workModelRequests.append(request)
        if failWorkModel { throw SmartSessionStoreTestError.unimplemented }
        if request.sessionID == "session-2", let secondSessionModel {
            return .init(found: true, sessionID: request.sessionID, model: secondSessionModel)
        }
        if let responseOverride { return responseOverride }''')
source = source.replace('private static func model(sessionID: String, revision: Int) -> ProvenanceSessionWorkModel {', 'private static func model(sessionID: String, revision: Int, semanticIDs: [String] = []) -> ProvenanceSessionWorkModel {')
source = source.replace('semanticInferenceIDs: [],\n                latestSemanticInferenceCreatedAt: nil', 'semanticInferenceIDs: semanticIDs,\n                latestSemanticInferenceCreatedAt: nil', 1)
source = source.replace('    func health() async throws -> ProvenanceEngineHealth {', '''    private var relatedBlocksRemaining = 0
    private var relatedStarts = 0
    private var relatedExpected = 0
    private var relatedStarted: CheckedContinuation<Void, Never>?
    private var relatedRelease: CheckedContinuation<Void, Never>?
    func holdRelated() { relatedBlocksRemaining = 1 }
    func holdRelatedTwice() { relatedBlocksRemaining = 2 }
    func waitForRelatedStart() async { await waitForRelatedCount(1) }
    func waitForRelatedCount(_ count: Int) async {
        if relatedStarts >= count { return }
        relatedExpected = count
        await withCheckedContinuation { relatedStarted = $0 }
    }
    func releaseRelated() { relatedRelease?.resume(); relatedRelease = nil }
    private var relatedAvailable = false
    private var relatedWrongTarget = false
    func setRelatedWrongTarget(_ value: Bool) { relatedWrongTarget = value }
    func setRelatedAvailable(_ value: Bool) { relatedAvailable = value }
    func relatedSessions(_ request: ProvenanceRelatedSessionRequest) async throws -> ProvenanceRelatedSessionResponse {
        relatedStarts += 1
        if relatedStarts >= relatedExpected {
            relatedStarted?.resume()
            relatedStarted = nil
        }
        if relatedBlocksRemaining > 0 && request.targetSessionID == "session-1" {
            relatedBlocksRemaining -= 1
            await withCheckedContinuation { relatedRelease = $0 }
        }
        guard relatedAvailable else { throw SmartSessionStoreTestError.unimplemented }
        let session = models[0].identity.session
        let metadata = ProvenanceRelatedSessionProjectionMetadata(revisionID: "r", projectionRuleID: "rule", projectionRuleVersion: "1", requestFingerprint: "q", contentFingerprint: "c", resultLimit: 5, exclusionLimit: 5, updatedAfter: nil, sourceEvidenceWatermark: nil, generatedAt: nil)
        let completeness = ProvenanceRelatedSessionCompleteness(status: "partial", evaluatedThroughSequence: nil, fields: [.init(field: "candidates", status: "partial", reason: "bounded")], notes: [])
        let projection = ProvenanceRelatedSessionProjection(targetSessionID: session.id, targetSession: session, targetSessionOutcomeProjection: nil, targetSessionWorkModelRevision: nil, projection: metadata, relatedSessions: [], excludedCandidates: [], completeness: completeness)
        return .init(found: true, targetSessionID: relatedWrongTarget ? "foreign" : session.id, projection: projection)
    }
    private var collisionAvailable = false
    func setCollisionAvailable(_ value: Bool) { collisionAvailable = value }
    func artifactCollisions(_ request: ProvenanceArtifactCollisionRequest) async throws -> ProvenanceArtifactCollisionResponse {
        guard collisionAvailable else { throw SmartSessionStoreTestError.unimplemented }
        let session = models[0].identity.session
        let metadata = ProvenanceArtifactCollisionProjectionMetadata(revisionID: "r", projectionRuleID: "rule", projectionRuleVersion: "1", requestFingerprint: "q", contentFingerprint: "c", resultLimit: 5, relatedSessionLimit: 20, exclusionLimit: 5, artifactPath: nil, normalizedArtifactPath: nil, updatedAfter: nil, staleBefore: nil, sourceEvidenceWatermark: nil, generatedAt: nil)
        let completeness = ProvenanceArtifactCollisionCompleteness(status: "partial", evaluatedThroughSequence: nil, fields: [.init(field: "candidates", status: "partial", reason: "bounded")], notes: [])
        let projection = ProvenanceArtifactCollisionProjection(targetSessionID: session.id, targetSession: session, targetSessionOutcomeProjection: nil, relatedSessionProjection: nil, projection: metadata, candidates: [], excludedCandidates: [], completeness: completeness)
        return .init(found: true, targetSessionID: session.id, projection: projection)
    }
    func health() async throws -> ProvenanceEngineHealth {''')
source = source.replace('''    func semanticMessages(
        _ request: ProvenanceSemanticMessageQueryRequest
    ) async throws -> ProvenanceSemanticMessageQueryResponse {
        ProvenanceSemanticMessageQueryResponse(records: [])''', '''    private var semanticFailure = false
    private var semanticRecords: [ProvenanceSemanticMessageRecord] = []
    func setSemanticRecords(_ value: [ProvenanceSemanticMessageRecord]) { semanticRecords = value }
    func setSemanticFailure(_ value: Bool) { semanticFailure = value }
    func semanticMessages(
        _ request: ProvenanceSemanticMessageQueryRequest
    ) async throws -> ProvenanceSemanticMessageQueryResponse {
        if semanticFailure { throw SmartSessionStoreTestError.unimplemented }
        return ProvenanceSemanticMessageQueryResponse(records: semanticRecords)''')
source += '''
extension AgentSessionSmartSessionStoreTests {
    @Test func failedReadMustNotReportAvailable() async {
        let client = SmartSessionStoreTestClient(model: Self.model(sessionID: "session-1", revision: 42))
        var instant = Date(timeIntervalSince1970: 100)
        let store = AgentSessionSmartSessionStore(client: client, now: { instant })
        guard case .available(let original) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Initial read was not available")
            return
        }
        await client.failNextReads()
        let refreshed = await store.refreshedSnapshot(sessionID: "session-1")
        #expect(refreshed.bridgePayload["status"] as? String == "failed")
        #expect(refreshed.bridgePayload["snapshot"] != nil)
        #expect(refreshed.bridgePayload["lastSuccessfulReadAt"] != nil)
        #expect(store.snapshot(sessionID: "session-1").bridgePayload["status"] as? String == "failed")
        #expect(original.identity.sessionID == "session-1")
        #expect(await client.sessionWorkModelRequestCount() == 2)
        instant = Date(timeIntervalSince1970: 200)
        let repeated = await store.refreshedSnapshot(sessionID: "session-1")
        #expect(repeated.bridgePayload["lastSuccessfulReadAt"] as? String == refreshed.bridgePayload["lastSuccessfulReadAt"] as? String)
        await client.restoreReads()
        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .available(original))
        #expect(store.snapshot(sessionID: "session-1") == .available(original))
    }

    @Test func overlapAfterCapturedModelDoesNotClaimNewRead() async {
        let initial = Self.model(sessionID: "session-1", revision: 42)
        let latest = Self.model(sessionID: "session-1", revision: 43)
        let client = SmartSessionStoreTestClient(models: [initial], materializedFactualRevisions: [42, 43])
        let store = AgentSessionSmartSessionStore(client: client)
        await client.holdRelated()
        let first = Task { await store.refreshedSnapshot(sessionID: "session-1") }
        await client.waitForRelatedStart()
        await client.setResponse(.init(found: true, sessionID: "session-1", model: latest))
        let (started, continuation) = AsyncStream<Void>.makeStream()
        let second = Task { @MainActor in
            continuation.yield(())
            return await store.refreshedSnapshot(sessionID: "session-1")
        }
        for await _ in started { break }
        await client.releaseRelated()
        guard case .available(let recovered) = await first.value,
              case .available(let joined) = await second.value else {
            Issue.record("Overlapping callers should converge on the new source")
            return
        }
        #expect(recovered.revision.factualRevision == 43)
        #expect(joined.revision.factualRevision == 43)
        #expect(await client.sessionWorkModelRequestCount() == 2)
    }

    @Test func semanticMessageFailureIsExplicitWithoutDiscardingFacts() async {
        let client = SmartSessionStoreTestClient(model: Self.model(sessionID: "session-1", revision: 42))
        let store = AgentSessionSmartSessionStore(client: client)
        await client.setSemanticFailure(true)
        guard case .available(let snapshot) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Factual model should remain available")
            return
        }
        #expect(snapshot.revision.factualRevision == 42)
        #expect(snapshot.bridgePayload["semanticMessagesReadStatus"] as? String == "unavailable")
        await client.setSemanticFailure(false)
        guard case .available(let recovered) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Semantic messages should recover")
            return
        }
        #expect(recovered.bridgePayload["semanticMessagesReadStatus"] as? String == "available")
    }

    @Test func cancellationAfterJoiningDoesNotPoisonActiveRead() async {
        let client = SmartSessionStoreTestClient(model: Self.model(sessionID: "session-1", revision: 42))
        let store = AgentSessionSmartSessionStore(client: client)
        await client.holdRelated()
        let first = Task { await store.refreshedSnapshot(sessionID: "session-1") }
        await client.waitForRelatedStart()
        let (started, continuation) = AsyncStream<Void>.makeStream()
        let second = Task { @MainActor in
            continuation.yield(())
            return await store.refreshedSnapshot(sessionID: "session-1")
        }
        for await _ in started { break }
        #expect(store.snapshot(sessionID: "session-1") == .failed(sessionID: "session-1"))
        second.cancel()
        await client.releaseRelated()
        guard case .available = await first.value else {
            Issue.record("Cancelled joiner must not prevent a healthy result")
            return
        }
        #expect(await second.value == .failed(sessionID: "session-1"))
    }

    @Test func overlapDuringFollowUpStopsAtTwoReadsAndRecoversOnRetry() async {
        let client = SmartSessionStoreTestClient(model: Self.model(sessionID: "session-1", revision: 42))
        let store = AgentSessionSmartSessionStore(client: client)
        await client.holdRelatedTwice()
        let first = Task { await store.refreshedSnapshot(sessionID: "session-1") }
        await client.waitForRelatedCount(1)
        let (startedSecond, secondSignal) = AsyncStream<Void>.makeStream()
        let second = Task { @MainActor in secondSignal.yield(()); return await store.refreshedSnapshot(sessionID: "session-1") }
        for await _ in startedSecond { break }
        await client.releaseRelated()
        await client.waitForRelatedCount(2)
        let (startedThird, thirdSignal) = AsyncStream<Void>.makeStream()
        let third = Task { @MainActor in thirdSignal.yield(()); return await store.refreshedSnapshot(sessionID: "session-1") }
        for await _ in startedThird { break }
        await client.releaseRelated()
        #expect(await first.value == .failed(sessionID: "session-1"))
        #expect(await second.value == .failed(sessionID: "session-1"))
        #expect(await third.value == .failed(sessionID: "session-1"))
        #expect(await client.sessionWorkModelRequestCount() == 2)
        guard case .available = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("A later non-overlapping retry must recover")
            return
        }
    }

    @Test func foreignSemanticMessagesAreUnavailableAndLimitDoesNotImplyComplete() async {
        func message(_ id: String, scope: ProvenanceSemanticInferenceScope, scopeID: String) -> ProvenanceSemanticMessageRecord {
            .init(id: id, semanticInferenceID: id, semanticInferenceKind: "test", scope: scope, scopeID: scopeID,
                  concisePhrase: "Observed", expandedMeaning: "Observed", structuredSemanticPayload: .object([:]),
                  supportingEvidenceRefs: [], supportingFactualRevision: 42, confidence: .high, specificity: .granular,
                  presentationProducerType: .rule, presentationProducerID: "test", presentationProducerVersion: "1",
                  presentationPolicyID: "test", presentationPolicyVersion: "1", localeIdentifier: nil, createdAt: Date(timeIntervalSince1970: 100))
        }
        for foreign in [message("wrong-id", scope: .session, scopeID: "session-2"), message("wrong-scope", scope: .thread, scopeID: "session-1")] {
            let client = SmartSessionStoreTestClient(model: Self.model(sessionID: "session-1", revision: 42))
            let store = AgentSessionSmartSessionStore(client: client)
            await client.setSemanticRecords([foreign])
            guard case .available(let snapshot) = await store.refreshedSnapshot(sessionID: "session-1") else {
                Issue.record("Factual model should remain available")
                continue
            }
            #expect(snapshot.semanticMessages.isEmpty)
            #expect(snapshot.semanticMessagesReadStatus == "unavailable")
        }
        let client = SmartSessionStoreTestClient(model: Self.model(sessionID: "session-1", revision: 42))
        let store = AgentSessionSmartSessionStore(client: client)
        await client.setSemanticRecords((0..<20).map { message("m-\($0)", scope: .session, scopeID: "session-1") })
        guard case .available(let snapshot) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Factual model should remain available")
            return
        }
        #expect(snapshot.semanticMessages.count == 20)
        #expect(snapshot.bridgePayload["semanticMessagesCoverage"] as? String == "unknown")
    }

    @Test func burstIsBoundedAndSeparateSessionCanProgress() async {
        let client = SmartSessionStoreTestClient(model: Self.model(sessionID: "session-1", revision: 42))
        await client.setSecondSessionModel(Self.model(sessionID: "session-2", revision: 42))
        let store = AgentSessionSmartSessionStore(client: client)
        await client.holdRelated()
        let first = Task { await store.refreshedSnapshot(sessionID: "session-1") }
        await client.waitForRelatedStart()
        var joined: [Task<AgentSessionSmartSessionReadResult, Never>] = []
        for _ in 0..<16 {
            let (started, signal) = AsyncStream<Void>.makeStream()
            joined.append(Task { @MainActor in signal.yield(()); return await store.refreshedSnapshot(sessionID: "session-1") })
            for await _ in started { break }
        }
        #expect(store.snapshot(sessionID: "session-1") == .failed(sessionID: "session-1"))
        let (started, signal) = AsyncStream<Void>.makeStream()
        let excess = Task { @MainActor in signal.yield(()); return await store.refreshedSnapshot(sessionID: "session-1") }
        for await _ in started { break }
        guard case .available = await store.refreshedSnapshot(sessionID: "session-2") else {
            Issue.record("An unrelated session must not wait for the held read")
            await client.releaseRelated()
            return
        }
        await client.releaseRelated()
        #expect(await excess.value == .failed(sessionID: "session-1"))
        guard case .available = await first.value else {
            Issue.record("Admitted callers should converge after a bounded follow-up")
            return
        }
        for task in joined { guard case .available = await task.value else { Issue.record("Admitted waiter did not converge"); continue } }
        #expect(await client.sessionWorkModelRequestCount() == 3)
    }

    @Test func failedReadWithoutCacheStaysFailed() async {
        let client = SmartSessionStoreTestClient(model: Self.model(sessionID: "session-1", revision: 42))
        let store = AgentSessionSmartSessionStore(client: client)
        await client.failNextReads()
        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .failed(sessionID: "session-1"))
        #expect(store.snapshot(sessionID: "session-1") == .failed(sessionID: "session-1"))
        #expect(store.snapshot(sessionID: "session-2").bridgePayload["status"] as? String == "notFound")
    }

    @Test func inconsistentResponseKeepsCachedFactsAndNotFoundClears() async {
        let original = Self.model(sessionID: "session-1", revision: 42)
        let foreign = Self.model(sessionID: "session-2", revision: 42)
        let client = SmartSessionStoreTestClient(model: original)
        let store = AgentSessionSmartSessionStore(client: client)
        guard case .available = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Initial read was not available")
            return
        }
        let bad: [ProvenanceSessionWorkModelResponse] = [
            .init(found: true, sessionID: "session-1", model: nil),
            .init(found: false, sessionID: "session-1", model: original),
            .init(found: true, sessionID: "session-2", model: original),
            .init(found: true, sessionID: "session-1", model: foreign),
        ]
        for response in bad {
            await client.setResponse(response)
            let result = await store.refreshedSnapshot(sessionID: "session-1")
            #expect(result.bridgePayload["status"] as? String == "failed")
            #expect(result.bridgePayload["snapshot"] != nil)
        }
        await client.setResponse(.init(found: false, reason: "missing", sessionID: "session-1", model: nil))
        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .notFound(sessionID: "session-1", reason: "missing"))
        #expect(store.snapshot(sessionID: "session-1") == .notFound(sessionID: "session-1", reason: nil))
    }

    @Test func awarenessRefreshDoesNotFreezeAnUnchangedPrimarySnapshot() async {
        let client = SmartSessionStoreTestClient(model: Self.model(sessionID: "session-1", revision: 42))
        let store = AgentSessionSmartSessionStore(client: client)
        guard case .available(let initial) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Initial read unavailable")
            return
        }
        #expect(initial.crossSessionAwareness.status == "unavailable")
        #expect(initial.crossSessionAwareness.bridgePayload["relatedReadStatus"] as? String == "unavailable")
        #expect(initial.crossSessionAwareness.bridgePayload["collisionReadStatus"] as? String == "unavailable")
        await client.setRelatedAvailable(true)
        guard case .available(let refreshed) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Independent awareness changed without a primary revision")
            return
        }
        #expect(refreshed.crossSessionAwareness.status == "available")
        #expect(refreshed.crossSessionAwareness.bridgePayload["relatedReadStatus"] as? String == "partial")
        let fields = refreshed.crossSessionAwareness.bridgePayload["relatedAvailability"] as? [[String: String]]
        #expect(fields?.first?["reason"] == "bounded")
        #expect(refreshed.crossSessionAwareness.bridgePayload["collisionReadStatus"] as? String == "unavailable")
        await client.setCollisionAvailable(true)
        guard case .available(let both) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Both sources should be available")
            return
        }
        #expect(both.crossSessionAwareness.bridgePayload["relatedReadStatus"] as? String == "partial")
        #expect(both.crossSessionAwareness.bridgePayload["collisionReadStatus"] as? String == "partial")
        await client.setRelatedWrongTarget(true)
        guard case .available(let wrongTarget) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Wrong-target related response must not affect primary facts")
            return
        }
        #expect(wrongTarget.crossSessionAwareness.bridgePayload["relatedReadStatus"] as? String == "unavailable")
        #expect(wrongTarget.crossSessionAwareness.bridgePayload["collisionReadStatus"] as? String == "partial")
        await client.setRelatedAvailable(false)
        guard case .available(let collisionOnly) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Collision source should be available")
            return
        }
        #expect(collisionOnly.crossSessionAwareness.bridgePayload["relatedReadStatus"] as? String == "unavailable")
        #expect(collisionOnly.crossSessionAwareness.bridgePayload["collisionReadStatus"] as? String == "partial")
        await client.setCollisionAvailable(false)
        guard case .available(let unavailable) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Independent awareness failure froze primary snapshot")
            return
        }
        #expect(unavailable.crossSessionAwareness.status == "unavailable")
    }

    @Test func unknownFactualRevisionAndMissingTimestampsDoNotOrder() {
        let workKnown = ProvenanceSessionWorkModelRevision(factualRevision: 42, semanticInferenceIDs: ["a"], latestSemanticInferenceCreatedAt: nil)
        let workUnknown = ProvenanceSessionWorkModelRevision(factualRevision: nil, semanticInferenceIDs: ["a"], latestSemanticInferenceCreatedAt: Date(timeIntervalSince1970: 100))
        let known = AgentSessionSmartSessionSnapshot.Revision(workModelRevision: workKnown, semanticMessageCount: 1, latestSemanticMessageCreatedAt: nil)
        let unknown = AgentSessionSmartSessionSnapshot.Revision(workModelRevision: workUnknown, semanticMessageCount: 1, latestSemanticMessageCreatedAt: nil)
        #expect(!known.isNewerThan(unknown))
        #expect(!unknown.isNewerThan(known))
        let later = ProvenanceSessionWorkModelRevision(factualRevision: 42, semanticInferenceIDs: ["a"], latestSemanticInferenceCreatedAt: Date(timeIntervalSince1970: 100))
        let withTime = AgentSessionSmartSessionSnapshot.Revision(workModelRevision: later, semanticMessageCount: 1, latestSemanticMessageCreatedAt: nil)
        #expect(!withTime.isNewerThan(known))
        #expect(!known.isNewerThan(withTime))
        let olderWork = ProvenanceSessionWorkModelRevision(schemaVersion: 3, factualRevision: 42, semanticInferenceIDs: ["a"], latestSemanticInferenceCreatedAt: Date(timeIntervalSince1970: 50))
        let older = AgentSessionSmartSessionSnapshot.Revision(workModelRevision: olderWork, semanticMessageCount: 1, latestSemanticMessageCreatedAt: nil)
        #expect(withTime.isNewerThan(older))
        let foreignSchemaWork = ProvenanceSessionWorkModelRevision(schemaVersion: 2, factualRevision: 42, semanticInferenceIDs: ["a"], latestSemanticInferenceCreatedAt: Date(timeIntervalSince1970: 200))
        let foreignSchema = AgentSessionSmartSessionSnapshot.Revision(workModelRevision: foreignSchemaWork, semanticMessageCount: 1, latestSemanticMessageCreatedAt: nil)
        #expect(!foreignSchema.isNewerThan(withTime))
        #expect(!withTime.isNewerThan(foreignSchema))
    }

    @Test func semanticCountsDoNotEstablishRevisionOrder() {
        let workOne = ProvenanceSessionWorkModelRevision(factualRevision: 42, semanticInferenceIDs: ["a"], latestSemanticInferenceCreatedAt: nil)
        let workTwo = ProvenanceSessionWorkModelRevision(factualRevision: 42, semanticInferenceIDs: ["a", "b"], latestSemanticInferenceCreatedAt: nil)
        let one = AgentSessionSmartSessionSnapshot.Revision(workModelRevision: workOne, semanticMessageCount: 1, latestSemanticMessageCreatedAt: nil)
        let twoIDs = AgentSessionSmartSessionSnapshot.Revision(workModelRevision: workTwo, semanticMessageCount: 1, latestSemanticMessageCreatedAt: nil)
        let twoMessages = AgentSessionSmartSessionSnapshot.Revision(workModelRevision: workOne, semanticMessageCount: 2, latestSemanticMessageCreatedAt: nil)
        #expect(!twoIDs.isNewerThan(one))
        #expect(!one.isNewerThan(twoIDs))
        #expect(!twoMessages.isNewerThan(one))
        #expect(!one.isNewerThan(twoMessages))
    }

    @Test func equallyRankedDifferentSemanticIDsAreNotCurrent() async {
        let first = Self.model(sessionID: "session-1", revision: 42, semanticIDs: ["a"])
        let second = Self.model(sessionID: "session-1", revision: 42, semanticIDs: ["b"])
        let client = SmartSessionStoreTestClient(models: [first, second], materializedFactualRevisions: [42, 42])
        let store = AgentSessionSmartSessionStore(client: client)
        guard case .available(let prior) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Initial read was not available")
            return
        }
        let result = await store.refreshedSnapshot(sessionID: "session-1")
        #expect(result.bridgePayload["status"] as? String == "failed")
        if case .stale(let snapshot, _) = result {
            #expect(snapshot.hasSamePrimaryContent(as: prior))
            #expect(snapshot.semanticMessagesReadStatus == "unavailable")
        }
        else { Issue.record("Expected last known snapshot as stale") }
    }

    @Test func olderModelCannotClaimCachedFactsAreCurrent() async {
        let client = SmartSessionStoreTestClient(models: [Self.model(sessionID: "session-1", revision: 42), Self.model(sessionID: "session-1", revision: 41)], materializedFactualRevisions: [42, 41])
        let store = AgentSessionSmartSessionStore(client: client)
        guard case .available = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Initial read was not available")
            return
        }
        #expect(await store.refreshedSnapshot(sessionID: "session-1").bridgePayload["status"] as? String == "failed")
        #expect(store.snapshot(sessionID: "session-1").bridgePayload["status"] as? String == "failed")
    }
}
'''
(package / 'Tests/StoreTests/SmartSessionStoreTests.swift').write_text(source)
PY
HOME="$task_root/home" CFFIXED_USER_HOME="$task_root/home" XDG_CACHE_HOME="$task_root/cache" XDG_CONFIG_HOME="$task_root/home" TMPDIR="$task_root/tmp" CLANG_MODULE_CACHE_PATH="$task_root/cache/clang" SWIFTPM_MODULECACHE_OVERRIDE="$task_root/cache/swift" swift test --package-path "$task_root/package" --scratch-path "$task_root/build" --filter AgentSessionSmartSessionStoreTests
