import BmuxFoundation
import Foundation
import SQLite3
import Testing

struct CodexMonitorLeaseTests {
    @Test(arguments: [true, false])
    func nextPromptRespectsPriorTurnCompletion(completedPriorTurn: Bool) async throws {
        let fixture = try CodexMonitorLeaseFixture()
        let snapshots = try await fixture.run(completedPriorTurn: completedPriorTurn)
        #expect(snapshots.first.active.count == 1)
        let first = try #require(snapshots.first.active.first)
        #expect(first.turnId == "turn-one")
        #expect(snapshots.first.depth == 1)
        #expect(snapshots.first.turns == ["turn-one"])
        #expect(snapshots.second.active.count == 1)
        let current = try #require(snapshots.second.active.first)
        for lease in [first, current] {
            #expect(lease.sessionId == fixture.session)
            #expect(lease.workspaceId == fixture.workspace)
            #expect(lease.surfaceId == fixture.surface)
        }
        if completedPriorTurn {
            #expect(current.turnId == "turn-two")
            #expect(current.leaseId != first.leaseId)
            #expect(snapshots.second.depth == 1)
            #expect(snapshots.second.turns == ["turn-two"])
            // Removal is normal retirement completion; a retained prior record must be marked retired.
            if let retired = snapshots.second.leases.first(where: { $0.leaseId == first.leaseId }) {
                #expect(retired.retiredAt != nil)
            }
        } else {
            #expect(current.turnId == "turn-one")
            #expect(current.leaseId == first.leaseId)
            #expect(current.retiredAt == nil)
            #expect(snapshots.second.depth == 2)
            #expect(snapshots.second.turns == ["turn-one", "turn-two"])
        }
    }

#if DEBUG
    @Test(arguments: [true, false])
    func monitorReportsPrivateInitializationFailure(newerSchema: Bool) async throws {
        let cli = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        let root = URL(fileURLWithPath: "/tmp", isDirectory: true)
            .appendingPathComponent("codex-init-debug-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = root.appendingPathComponent(".local/state/provenance-engine/provenance.sqlite")
        if newerSchema {
            try FileManager.default.createDirectory(at: database.deletingLastPathComponent(), withIntermediateDirectories: true)
            var handle: OpaquePointer?
            #expect(sqlite3_open(database.path, &handle) == SQLITE_OK)
            let opened = try #require(handle)
            defer { sqlite3_close(opened) }
            #expect(sqlite3_exec(opened, "PRAGMA user_version = 2147483647", nil, nil, nil) == SQLITE_OK)
        }
        let socket = root.appendingPathComponent("socket").path
        let log = root.appendingPathComponent("debug.log")
        let fixture = CLISocketFixture(path: socket) { _ in "OK" }
        let environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "BMUX_PROVENANCE_HOME": root.path,
            "BMUX_SOCKET_PATH": socket, "BMUX_DEBUG_LOG": log.path, "BMUX_CLI_SENTRY_DISABLED": "1",
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        ]
        let (result, _) = try await fixture.capture {
            await CommandRunner(environment: environment).run(
                directory: root.path, executable: cli,
                arguments: ["hooks", "codex", "monitor", "--workspace", "workspace-probe",
                            "--session", "session-probe", "--lease", root.appendingPathComponent("retired").path],
                timeout: 10
            )
        }
        #expect(!result.timedOut)
        #expect(result.exitStatus == 0)
        let text = try String(contentsOf: log, encoding: .utf8)
        let failureLines = text.split(separator: "\n").filter { $0.contains("codexMonitor.provenanceInitFailed") }
        #expect(failureLines.count == (newerSchema ? 1 : 0))
        for line in failureLines {
            #expect(!line.contains(root.path))
            #expect(!line.contains("session-probe"))
            #expect(!line.contains("unsupportedSchema"))
        }
    }
#endif

}
