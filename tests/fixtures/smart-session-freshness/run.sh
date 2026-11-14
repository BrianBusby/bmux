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
    func failNextReads() { failWorkModel = true }
    private let models: [ProvenanceSessionWorkModel]''')
source = source.replace('''        let index = workModelRequests.count
        workModelRequests.append(request)''', '''        let index = workModelRequests.count
        workModelRequests.append(request)
        if failWorkModel { throw SmartSessionStoreTestError.unimplemented }''')
source += '''
extension AgentSessionSmartSessionStoreTests {
    @Test func failedReadMustNotReportAvailable() async {
        let client = SmartSessionStoreTestClient(model: Self.model(sessionID: "session-1", revision: 42))
        let store = AgentSessionSmartSessionStore(client: client)
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
    }
}
'''
(package / 'Tests/StoreTests/SmartSessionStoreTests.swift').write_text(source)
PY
HOME="$task_root/home" CFFIXED_USER_HOME="$task_root/home" XDG_CACHE_HOME="$task_root/cache" XDG_CONFIG_HOME="$task_root/home" TMPDIR="$task_root/tmp" CLANG_MODULE_CACHE_PATH="$task_root/cache/clang" SWIFTPM_MODULECACHE_OVERRIDE="$task_root/cache/swift" swift test --package-path "$task_root/package" --scratch-path "$task_root/build" --filter failedReadMustNotReportAvailable
