import Foundation
import Testing

@testable import BmuxContextEfficiency

@Suite
struct CodexStateMetadataReaderChecks {
    @Test
    func standardStorageLocationUsesLocalStateDirectory() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
        let location = ContextEfficiencyStorageLocation(homeDirectory: home)

        #expect(location.directoryURL.path == "/Users/example/.local/state/bmux/context-efficiency")
        #expect(location.databaseURL.path == "/Users/example/.local/state/bmux/context-efficiency/bmux-context-efficiency.sqlite")
    }

    @Test
    func readsHighestCodexStateDatabaseFromSnapshotCopy() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let codexHome = directory.appendingPathComponent("codex-home", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        let rolloutURL = directory.appendingPathComponent("rollout-thread-new.jsonl")
        try Data("".utf8).write(to: rolloutURL)

        try createStateDatabase(
            at: codexHome.appendingPathComponent("state_5.sqlite"),
            rows: [
                StateRow(
                    id: "thread-old",
                    rolloutPath: nil,
                    tokensUsed: 10,
                    updatedAtMS: 1_780_000_000_000
                )
            ]
        )
        try createStateDatabase(
            at: codexHome.appendingPathComponent("state_7.sqlite"),
            rows: [
                StateRow(
                    id: "thread-new",
                    rolloutPath: rolloutURL.path,
                    cwd: "/repo/bmux",
                    title: "Phase 2 importer",
                    preview: "read-only telemetry",
                    firstUserMessage: "continue phase 2",
                    modelProvider: "openai",
                    model: "gpt-5",
                    reasoningEffort: "high",
                    approvalMode: "on-request",
                    sandboxPolicy: #"{"type":"workspace-write"}"#,
                    gitBranch: "context-efficiency",
                    gitOriginURL: "git@example.com:bmux.git",
                    cliVersion: "1.2.3",
                    tokensUsed: 900,
                    source: "codex",
                    createdAt: 1_780_000_000,
                    updatedAtMS: 1_780_000_600_000
                )
            ]
        )

        let reader = CodexStateMetadataReader(
            codexHomeURL: codexHome,
            temporaryDirectoryURL: directory
        )
        let snapshot = try await reader.readSnapshot(readAt: Date(timeIntervalSince1970: 1_780_001_000))

        #expect(snapshot.location.databasePath == codexHome.appendingPathComponent("state_7.sqlite").path)
        #expect(snapshot.location.codexHomePath == codexHome.path)
        #expect(snapshot.threadCount == 1)
        let thread = try #require(snapshot.threads.first)
        #expect(thread.id == "thread-new")
        #expect(thread.normalizedThreadID == "codex:thread-new")
        #expect(thread.rolloutPath == rolloutURL.path)
        #expect(thread.cwd == "/repo/bmux")
        #expect(thread.title == "Phase 2 importer")
        #expect(thread.preview == "read-only telemetry")
        #expect(thread.firstUserMessage == "continue phase 2")
        #expect(thread.modelProvider == "openai")
        #expect(thread.model == "gpt-5")
        #expect(thread.reasoningEffort == "high")
        #expect(thread.approvalMode == "on-request")
        #expect(thread.sandboxPolicyType == "workspace-write")
        #expect(thread.gitBranch == "context-efficiency")
        #expect(thread.gitOriginURL == "git@example.com:bmux.git")
        #expect(thread.cliVersion == "1.2.3")
        #expect(thread.tokensUsed == 900)
        #expect(thread.source == "codex")
        #expect(thread.createdAt == Date(timeIntervalSince1970: 1_780_000_000))
        #expect(thread.updatedAt == Date(timeIntervalSince1970: 1_780_000_600))

        let matched = try await reader.threadMetadata(forRollout: rolloutURL)
        #expect(matched?.id == "thread-new")
    }

    @Test
    func readsOlderStateSchemaWithSecondPrecisionTimestamps() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("state_5.sqlite")
        try createLegacyStateDatabase(at: databaseURL)

        let reader = CodexStateMetadataReader(
            databaseURL: databaseURL,
            temporaryDirectoryURL: directory
        )
        let snapshot = try await reader.readSnapshot()

        let thread = try #require(snapshot.threads.first)
        #expect(thread.id == "legacy-thread")
        #expect(thread.updatedAt == Date(timeIntervalSince1970: 1_780_000_100))
        #expect(thread.tokensUsed == 123)
    }

    private struct StateRow {
        var id: String
        var rolloutPath: String?
        var cwd: String?
        var title: String?
        var preview: String?
        var firstUserMessage: String?
        var modelProvider: String?
        var model: String?
        var reasoningEffort: String?
        var approvalMode: String?
        var sandboxPolicy: String?
        var gitBranch: String?
        var gitOriginURL: String?
        var cliVersion: String?
        var tokensUsed: Int64?
        var source: String?
        var createdAt: Double?
        var updatedAtMS: Int64?
    }

    private func createStateDatabase(at url: URL, rows: [StateRow]) throws {
        let database = try ContextEfficiencySQLiteDatabase(url: url)
        try database.execute(
            """
            CREATE TABLE threads (
                id TEXT PRIMARY KEY,
                rollout_path TEXT,
                cwd TEXT,
                title TEXT,
                preview TEXT,
                first_user_message TEXT,
                model_provider TEXT,
                model TEXT,
                reasoning_effort TEXT,
                approval_mode TEXT,
                sandbox_policy TEXT,
                git_branch TEXT,
                git_origin_url TEXT,
                cli_version TEXT,
                tokens_used INTEGER,
                source TEXT,
                created_at REAL,
                updated_at_ms INTEGER
            )
            """
        )
        for row in rows {
            let statement = try database.prepare(
                """
                INSERT INTO threads (
                    id, rollout_path, cwd, title, preview, first_user_message,
                    model_provider, model, reasoning_effort, approval_mode,
                    sandbox_policy, git_branch, git_origin_url, cli_version,
                    tokens_used, source, created_at, updated_at_ms
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """
            )
            defer { statement.finalize() }
            try statement.bind(row.id, at: 1)
            try statement.bind(row.rolloutPath, at: 2)
            try statement.bind(row.cwd, at: 3)
            try statement.bind(row.title, at: 4)
            try statement.bind(row.preview, at: 5)
            try statement.bind(row.firstUserMessage, at: 6)
            try statement.bind(row.modelProvider, at: 7)
            try statement.bind(row.model, at: 8)
            try statement.bind(row.reasoningEffort, at: 9)
            try statement.bind(row.approvalMode, at: 10)
            try statement.bind(row.sandboxPolicy, at: 11)
            try statement.bind(row.gitBranch, at: 12)
            try statement.bind(row.gitOriginURL, at: 13)
            try statement.bind(row.cliVersion, at: 14)
            try statement.bind(row.tokensUsed, at: 15)
            try statement.bind(row.source, at: 16)
            try statement.bind(row.createdAt, at: 17)
            try statement.bind(row.updatedAtMS, at: 18)
            _ = try statement.step()
        }
    }

    private func createLegacyStateDatabase(at url: URL) throws {
        let database = try ContextEfficiencySQLiteDatabase(url: url)
        try database.execute(
            """
            CREATE TABLE threads (
                id TEXT PRIMARY KEY,
                tokens_used INTEGER,
                created_at REAL,
                updated_at REAL,
                rollout_path TEXT
            )
            """
        )
        let statement = try database.prepare(
            """
            INSERT INTO threads (id, tokens_used, created_at, updated_at, rollout_path)
            VALUES (?, ?, ?, ?, ?)
            """
        )
        defer { statement.finalize() }
        try statement.bind("legacy-thread", at: 1)
        try statement.bind(Int64(123), at: 2)
        try statement.bind(1_780_000_000.0, at: 3)
        try statement.bind(1_780_000_100.0, at: 4)
        try statement.bind("/tmp/legacy-rollout.jsonl", at: 5)
        _ = try statement.step()
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-context-efficiency-checks")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
