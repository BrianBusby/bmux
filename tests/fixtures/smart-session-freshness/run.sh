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
    func setResponse(_ response: ProvenanceSessionWorkModelResponse) { responseOverride = response }
    func failNextReads() { failWorkModel = true }
    func restoreReads() { failWorkModel = false }
    private let models: [ProvenanceSessionWorkModel]''')
source = source.replace('''        let index = workModelRequests.count
        workModelRequests.append(request)''', '''        let index = workModelRequests.count
        workModelRequests.append(request)
        if failWorkModel { throw SmartSessionStoreTestError.unimplemented }
        if let responseOverride { return responseOverride }''')
source = source.replace('private static func model(sessionID: String, revision: Int) -> ProvenanceSessionWorkModel {', 'private static func model(sessionID: String, revision: Int, semanticIDs: [String] = []) -> ProvenanceSessionWorkModel {')
source = source.replace('semanticInferenceIDs: [],\n                latestSemanticInferenceCreatedAt: nil', 'semanticInferenceIDs: semanticIDs,\n                latestSemanticInferenceCreatedAt: nil', 1)
source = source.replace('    func health() async throws -> ProvenanceEngineHealth {', '''    private var relatedAvailable = false
    private var relatedWrongTarget = false
    func setRelatedWrongTarget(_ value: Bool) { relatedWrongTarget = value }
    func setRelatedAvailable(_ value: Bool) { relatedAvailable = value }
    func relatedSessions(_ request: ProvenanceRelatedSessionRequest) async throws -> ProvenanceRelatedSessionResponse {
        guard relatedAvailable else { throw SmartSessionStoreTestError.unimplemented }
        let session = models[0].identity.session
        let metadata = ProvenanceRelatedSessionProjectionMetadata(revisionID: "r", projectionRuleID: "rule", projectionRuleVersion: "1", requestFingerprint: "q", contentFingerprint: "c", resultLimit: 5, exclusionLimit: 5, updatedAfter: nil, sourceEvidenceWatermark: nil, generatedAt: nil)
        let completeness = ProvenanceRelatedSessionCompleteness(status: "partial", evaluatedThroughSequence: nil, fields: [], notes: [])
        let projection = ProvenanceRelatedSessionProjection(targetSessionID: session.id, targetSession: session, targetSessionOutcomeProjection: nil, targetSessionWorkModelRevision: nil, projection: metadata, relatedSessions: [], excludedCandidates: [], completeness: completeness)
        return .init(found: true, targetSessionID: relatedWrongTarget ? "foreign" : session.id, projection: projection)
    }
    private var collisionAvailable = false
    func setCollisionAvailable(_ value: Bool) { collisionAvailable = value }
    func artifactCollisions(_ request: ProvenanceArtifactCollisionRequest) async throws -> ProvenanceArtifactCollisionResponse {
        guard collisionAvailable else { throw SmartSessionStoreTestError.unimplemented }
        let session = models[0].identity.session
        let metadata = ProvenanceArtifactCollisionProjectionMetadata(revisionID: "r", projectionRuleID: "rule", projectionRuleVersion: "1", requestFingerprint: "q", contentFingerprint: "c", resultLimit: 5, relatedSessionLimit: 20, exclusionLimit: 5, artifactPath: nil, normalizedArtifactPath: nil, updatedAfter: nil, staleBefore: nil, sourceEvidenceWatermark: nil, generatedAt: nil)
        let completeness = ProvenanceArtifactCollisionCompleteness(status: "partial", evaluatedThroughSequence: nil, fields: [], notes: [])
        let projection = ProvenanceArtifactCollisionProjection(targetSessionID: session.id, targetSession: session, targetSessionOutcomeProjection: nil, relatedSessionProjection: nil, projection: metadata, candidates: [], excludedCandidates: [], completeness: completeness)
        return .init(found: true, targetSessionID: session.id, projection: projection)
    }
    func health() async throws -> ProvenanceEngineHealth {''')
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
        #expect(refreshed.crossSessionAwareness.bridgePayload["relatedReadStatus"] as? String == "available")
        #expect(refreshed.crossSessionAwareness.bridgePayload["collisionReadStatus"] as? String == "unavailable")
        await client.setCollisionAvailable(true)
        guard case .available(let both) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Both sources should be available")
            return
        }
        #expect(both.crossSessionAwareness.bridgePayload["relatedReadStatus"] as? String == "available")
        #expect(both.crossSessionAwareness.bridgePayload["collisionReadStatus"] as? String == "available")
        await client.setRelatedWrongTarget(true)
        guard case .available(let wrongTarget) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Wrong-target related response must not affect primary facts")
            return
        }
        #expect(wrongTarget.crossSessionAwareness.bridgePayload["relatedReadStatus"] as? String == "unavailable")
        #expect(wrongTarget.crossSessionAwareness.bridgePayload["collisionReadStatus"] as? String == "available")
        await client.setRelatedAvailable(false)
        guard case .available(let collisionOnly) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Collision source should be available")
            return
        }
        #expect(collisionOnly.crossSessionAwareness.bridgePayload["relatedReadStatus"] as? String == "unavailable")
        #expect(collisionOnly.crossSessionAwareness.bridgePayload["collisionReadStatus"] as? String == "available")
        await client.setCollisionAvailable(false)
        guard case .available(let unavailable) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Independent awareness failure froze primary snapshot")
            return
        }
        #expect(unavailable.crossSessionAwareness.status == "unavailable")
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
        if case .stale(let snapshot, _) = result { #expect(snapshot == prior) }
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
