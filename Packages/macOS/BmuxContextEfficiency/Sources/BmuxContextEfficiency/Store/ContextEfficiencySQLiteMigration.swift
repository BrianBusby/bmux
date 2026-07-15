import Foundation

struct ContextEfficiencySQLiteMigration {
    let schemaVersion: Int32 = 1

    func migrateIfNeeded(database: ContextEfficiencySQLiteDatabase) throws {
        let version = try database.userVersion
        guard version <= schemaVersion else {
            throw ContextEfficiencyStoreError.unsupportedSchema(found: version, supported: schemaVersion)
        }
        guard version == 0 else {
            return
        }
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            for statement in schemaStatements {
                try database.execute(statement)
            }
            try database.execute("PRAGMA user_version = \(schemaVersion)")
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    private var schemaStatements: [String] {
        [
            """
            CREATE TABLE schema_migrations (
                version INTEGER PRIMARY KEY,
                applied_at REAL NOT NULL
            )
            """,
            """
            INSERT INTO schema_migrations (version, applied_at)
            VALUES (1, strftime('%s', 'now'))
            """,
            """
            CREATE TABLE import_sources (
                source_path TEXT PRIMARY KEY,
                source_type TEXT NOT NULL,
                file_size INTEGER NOT NULL,
                modified_at REAL,
                first_seen_at REAL NOT NULL,
                last_seen_at REAL NOT NULL,
                parser_version INTEGER NOT NULL
            )
            """,
            """
            CREATE TABLE import_cursors (
                source_path TEXT PRIMARY KEY,
                byte_offset INTEGER NOT NULL,
                line_number INTEGER NOT NULL,
                file_size INTEGER NOT NULL,
                parser_version INTEGER NOT NULL,
                updated_at REAL NOT NULL
            )
            """,
            """
            CREATE TABLE evidence_artifacts (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                storage_location TEXT NOT NULL,
                content_hash TEXT,
                byte_count INTEGER NOT NULL,
                estimated_tokens INTEGER,
                producer_event_id TEXT,
                created_at REAL NOT NULL,
                retention_policy TEXT NOT NULL
            )
            """,
            """
            CREATE TABLE agent_threads (
                id TEXT PRIMARY KEY,
                external_thread_id TEXT,
                rollout_path TEXT,
                model TEXT,
                reasoning_effort TEXT,
                cwd TEXT,
                first_observed_at REAL,
                last_observed_at REAL,
                cumulative_input_tokens INTEGER,
                cumulative_cached_input_tokens INTEGER,
                cumulative_non_cached_input_tokens INTEGER,
                cumulative_output_tokens INTEGER,
                cumulative_reasoning_output_tokens INTEGER,
                cumulative_total_tokens INTEGER,
                estimated_context_tokens INTEGER,
                context_window_tokens INTEGER,
                model_call_count INTEGER NOT NULL DEFAULT 0,
                compaction_count INTEGER NOT NULL DEFAULT 0,
                updated_at REAL NOT NULL
            )
            """,
            """
            CREATE TABLE rollout_events (
                id TEXT PRIMARY KEY,
                source_path TEXT NOT NULL,
                byte_offset INTEGER NOT NULL,
                line_number INTEGER NOT NULL,
                parser_version INTEGER NOT NULL,
                thread_id TEXT NOT NULL,
                kind TEXT NOT NULL,
                rollout_type TEXT,
                payload_type TEXT,
                timestamp REAL,
                imported_at REAL NOT NULL
            )
            """,
            """
            CREATE TABLE parser_errors (
                id TEXT PRIMARY KEY,
                source_path TEXT NOT NULL,
                byte_offset INTEGER NOT NULL,
                line_number INTEGER NOT NULL,
                parser_version INTEGER NOT NULL,
                thread_id TEXT NOT NULL,
                rollout_type TEXT,
                message TEXT NOT NULL,
                imported_at REAL NOT NULL
            )
            """,
            """
            CREATE TABLE token_telemetry_events (
                id TEXT PRIMARY KEY,
                thread_id TEXT NOT NULL,
                timestamp REAL,
                source_path TEXT NOT NULL,
                byte_offset INTEGER NOT NULL,
                line_number INTEGER NOT NULL,
                parser_version INTEGER NOT NULL,
                input_tokens INTEGER,
                cached_input_tokens INTEGER,
                non_cached_input_tokens INTEGER,
                output_tokens INTEGER,
                reasoning_output_tokens INTEGER,
                total_tokens INTEGER,
                estimated_context_tokens INTEGER,
                context_window_tokens INTEGER,
                duplicate_fingerprint TEXT NOT NULL,
                imported_at REAL NOT NULL
            )
            """,
            """
            CREATE TABLE model_calls (
                id TEXT PRIMARY KEY,
                thread_id TEXT NOT NULL,
                timestamp REAL,
                source_path TEXT NOT NULL,
                byte_offset INTEGER NOT NULL,
                line_number INTEGER NOT NULL,
                parser_version INTEGER NOT NULL,
                input_tokens INTEGER,
                cached_input_tokens INTEGER,
                non_cached_input_tokens INTEGER,
                output_tokens INTEGER,
                reasoning_output_tokens INTEGER,
                total_tokens INTEGER,
                estimated_context_tokens INTEGER,
                context_window_tokens INTEGER,
                telemetry_source TEXT NOT NULL,
                telemetry_confidence TEXT NOT NULL,
                imported_at REAL NOT NULL
            )
            """,
            """
            CREATE TABLE tool_calls (
                id TEXT PRIMARY KEY,
                thread_id TEXT NOT NULL,
                call_id TEXT,
                tool_name TEXT,
                command_summary TEXT,
                arguments_byte_count INTEGER NOT NULL,
                timestamp REAL,
                source_path TEXT NOT NULL,
                byte_offset INTEGER NOT NULL,
                line_number INTEGER NOT NULL,
                parser_version INTEGER NOT NULL,
                imported_at REAL NOT NULL
            )
            """,
            """
            CREATE TABLE tool_outputs (
                id TEXT PRIMARY KEY,
                thread_id TEXT NOT NULL,
                call_id TEXT,
                output_byte_count INTEGER NOT NULL,
                estimated_original_tokens INTEGER NOT NULL,
                raw_output_reference_count INTEGER NOT NULL,
                timestamp REAL,
                source_path TEXT NOT NULL,
                byte_offset INTEGER NOT NULL,
                line_number INTEGER NOT NULL,
                parser_version INTEGER NOT NULL,
                imported_at REAL NOT NULL
            )
            """,
            "CREATE INDEX idx_rollout_events_thread ON rollout_events(thread_id, timestamp)",
            "CREATE INDEX idx_model_calls_thread ON model_calls(thread_id, timestamp)",
            "CREATE INDEX idx_model_calls_timestamp ON model_calls(timestamp)",
            "CREATE INDEX idx_token_telemetry_thread ON token_telemetry_events(thread_id, timestamp)",
            "CREATE INDEX idx_tool_calls_thread ON tool_calls(thread_id, timestamp)",
            "CREATE INDEX idx_tool_outputs_thread ON tool_outputs(thread_id, timestamp)",
            "CREATE INDEX idx_parser_errors_thread ON parser_errors(thread_id, imported_at)",
        ]
    }
}
