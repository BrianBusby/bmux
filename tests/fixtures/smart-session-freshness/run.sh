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
