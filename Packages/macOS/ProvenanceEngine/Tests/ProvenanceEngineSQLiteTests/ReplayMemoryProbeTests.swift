import Darwin
import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

#if DEBUG
private enum ReplayMemoryLimitExceeded: Error { case exceeded }
private extension ProvenanceSQLiteRepository {
    func setReplayProgressObserver(_ observer: (@Sendable () throws -> Void)?) {
        replayProgressForTesting = observer
    }
}
#endif

/// Opt-in synthetic scale probe. Never points at a user's database.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["BMUX_COLLISION_BENCH_STAGE"] != nil))
struct ReplayMemoryProbeTests {
    @Test
    func syntheticLedger() async throws {
        let env = ProcessInfo.processInfo.environment
        let path = try #require(env["BMUX_COLLISION_BENCH_PATH"])
        let stage = try #require(env["BMUX_COLLISION_BENCH_STAGE"])
        let count = Int(env["BMUX_COLLISION_BENCH_COUNT"] ?? "100000") ?? 100_000
        let url = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
        let temporaryRoot = URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path + "/bmux-collision-"
        guard url.path.hasPrefix(temporaryRoot) else {
            throw CocoaError(.fileWriteNoPermission)
        }
        let started = Date()
        if stage == "seed" {
            let repository = try ProvenanceSQLiteRepository(url: url, migrations: ProvenanceSQLiteRepository.migrations)
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let session = ProvenanceSessionRecord(id: "synthetic-session", agentKind: "codex", workspaceID: nil,
                surfaceID: nil, worktreeID: nil, cwd: nil, status: "active", startedAt: now, updatedAt: now)
            try await repository.appendEvent(ProvenanceEvent(id: "synthetic-session-event", eventType: .sessionObserved,
                timestamp: now, sessionID: session.id, source: .observed, confidence: .high,
                payload: ProvenanceEventPayload(session: session)))
            let turn = ProvenanceCodingAgentTurnRecord(id: "synthetic-turn", sessionID: session.id,
                threadID: nil, provider: "codex", providerTurnID: "synthetic-provider", status: "started", model: nil,
                effort: nil, startedAt: now, completedAt: nil, updatedAt: now, source: .observed, confidence: .high)
            let payload = try #require(String(data: JSONEncoder().encode(ProvenanceEventPayload(codingAgentTurn: turn)), encoding: .utf8))
            let database = try ProvenanceSQLiteDatabase(url: url)
            try database.execute("BEGIN IMMEDIATE")
            let statement = try database.prepare("""
                INSERT INTO provenance_events(id, schema_version, event_type, timestamp_seconds, session_id, source, confidence, payload_json)
                VALUES (?, 1, ?, 1800000000, 'synthetic-session', 'observed', 'high',
                    json_set(?, '$.codingAgentTurn.id', ?, '$.codingAgentTurn.providerTurnID', ?))
                """)
            defer { statement.finalize() }
            for index in 0..<count {
                let identity = "synthetic-turn-\(index / 10)"
                try statement.bind("synthetic-event-\(index)", at: 1)
                try statement.bind(ProvenanceEventType.codingAgentTurnObserved.rawValue, at: 2)
                try statement.bind(payload, at: 3)
                try statement.bind(identity, at: 4)
                try statement.bind(identity, at: 5)
                _ = try statement.step()
                statement.reset()
            }
            try database.execute("COMMIT")
            try database.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        } else {
            let repository = try ProvenanceSQLiteRepository(url: url)
            if stage == "replay" {
#if DEBUG
                if let value = env["BMUX_COLLISION_MAX_RSS_BYTES"], let maximum = Int(value) {
                    await repository.setReplayProgressObserver {
                        var usage = rusage()
                        getrusage(RUSAGE_SELF, &usage)
                        if usage.ru_maxrss > maximum { throw ReplayMemoryLimitExceeded.exceeded }
                    }
                }
#endif
                let replayed = try await repository.rebuildProjectionsFromEventLedger(batchSize: 256)
                #expect(replayed == count + 1)
            } else if stage == "read" {
                let result = try await repository.factualSessionProjection(.init(sessionID: "synthetic-session", turnLimit: 12))
                #expect(result.found)
                #expect((result.snapshot?.turns.count ?? 0) <= 12)
            } else {
                #expect(stage == "open")
            }
        }
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        let userCPU = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
        let systemCPU = Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
        print("COLLISION_BENCH stage=\(stage) events=\(count + 1) elapsed_seconds=\(Date().timeIntervalSince(started)) user_cpu_seconds=\(userCPU) system_cpu_seconds=\(systemCPU) max_rss_bytes=\(usage.ru_maxrss)")
    }
}
