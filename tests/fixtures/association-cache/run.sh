#!/bin/bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/../../.." && pwd)"
task_root="$(mktemp -d /tmp/bmux-association-cache.XXXXXXXX)"
trap 'rm -rf "$task_root"' EXIT
mkdir -p "$task_root/package/Sources/Store" "$task_root/package/Tests/StoreTests" "$task_root/home" "$task_root/cache" "$task_root/tmp"
cp "$repo/Sources/WorkProvenance/WorkspaceCodingAgentSessionAssociationStore.swift" "$task_root/package/Sources/Store/"
cp "$repo/tests/fixtures/association-cache/AssociationCacheFailureTests.swift" "$task_root/package/Tests/StoreTests/"
cat > "$task_root/package/Sources/Store/BreadcrumbStub.swift" <<'SWIFT'
import Foundation
enum StartupBreadcrumbLog {
    static func append(_ name: String, fields: [String: String]) {}
}
SWIFT
python3 - "$repo" "$task_root/package/Package.swift" <<'PY'
import json, pathlib, sys
repo, target = sys.argv[1:]
manifest = '''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "FactualCacheFixture", platforms: [.macOS(.v13)], dependencies: [.package(path: %s)], targets: [.target(name: "Store", dependencies: [.product(name: "ProvenanceEngineContracts", package: "ProvenanceEngine")]), .testTarget(name: "StoreTests", dependencies: ["Store", .product(name: "ProvenanceEngineContracts", package: "ProvenanceEngine")])])
''' % json.dumps(repo + '/Packages/macOS/ProvenanceEngine')
pathlib.Path(target).write_text(manifest)
PY
HOME="$task_root/home" CFFIXED_USER_HOME="$task_root/home" XDG_CACHE_HOME="$task_root/cache" XDG_CONFIG_HOME="$task_root/home" TMPDIR="$task_root/tmp" CLANG_MODULE_CACHE_PATH="$task_root/cache/clang" SWIFTPM_MODULECACHE_OVERRIDE="$task_root/cache/swift" swift test --package-path "$task_root/package" --scratch-path "$task_root/build" --filter AssociationCacheFailureTests
