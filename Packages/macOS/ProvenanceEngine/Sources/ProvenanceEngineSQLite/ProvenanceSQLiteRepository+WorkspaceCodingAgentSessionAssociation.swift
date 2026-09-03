import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    static let workspaceCodingAgentSessionAssociationMigrations = [
        ProvenanceSQLiteMigration(
            version: 25,
            statements: [
                """
                CREATE TABLE provenance_workspace_coding_agent_session_associations (
                    id TEXT PRIMARY KEY NOT NULL,
                    workspace_id TEXT NOT NULL,
                    session_id TEXT NOT NULL,
                    agent_kind TEXT NOT NULL,
                    raw_session_id TEXT,
                    canonical_session_id TEXT NOT NULL,
                    surface_id TEXT,
                    repository_id TEXT,
                    worktree_id TEXT,
                    current_directory TEXT,
                    source_path TEXT NOT NULL,
                    stage TEXT NOT NULL,
                    reason_code TEXT,
                    retryable INTEGER NOT NULL,
                    first_observed_at_seconds REAL NOT NULL,
                    prompt_observed_at_seconds REAL,
                    last_observed_at_seconds REAL NOT NULL,
                    last_transition_at_seconds REAL NOT NULL,
                    latest_event_id TEXT,
                    latest_event_sequence INTEGER
                )
                """,
                """
                CREATE INDEX provenance_workspace_coding_agent_session_associations_workspace_index
                ON provenance_workspace_coding_agent_session_associations (
                    workspace_id,
                    agent_kind,
                    prompt_observed_at_seconds,
                    last_observed_at_seconds,
                    latest_event_sequence
                )
                """,
                """
                CREATE INDEX provenance_workspace_coding_agent_session_associations_session_index
                ON provenance_workspace_coding_agent_session_associations (
                    session_id,
                    workspace_id,
                    agent_kind
                )
                """,
                """
                UPDATE provenance_metadata
                SET value = '25'
                WHERE key = 'schema_version'
                """,
            ]
        ),
    ]

    func workspaceCodingAgentSessionAssociationRecord(
        _ request: ProvenanceWorkspaceCodingAgentSessionAssociationRequest
    ) throws -> ProvenanceWorkspaceCodingAgentSessionAssociationResponse {
        let workspaceID = Self.trimmedNonEmpty(request.workspaceID) ?? request.workspaceID
        let agentKind = Self.trimmedNonEmpty(request.agentKind) ?? "codex"
        guard !workspaceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let readiness = ProvenanceWorkspaceCodingAgentSessionReadiness(
                status: .unsupportedOrUnassociatedSession,
                workspaceID: workspaceID,
                agentKind: agentKind,
                stage: "association_read",
                reasonCode: "empty_workspace_id",
                retryable: false
            )
            return ProvenanceWorkspaceCodingAgentSessionAssociationResponse(
                found: false,
                reason: "empty_workspace_id",
                workspaceID: workspaceID,
                agentKind: agentKind,
                association: nil,
                readiness: readiness
            )
        }

        guard let association = try workspaceCodingAgentSessionAssociation(
            workspaceID: workspaceID,
            agentKind: agentKind
        ) else {
            let readiness = ProvenanceWorkspaceCodingAgentSessionReadiness(
                status: .noSupportedCodingAgentDetected,
                workspaceID: workspaceID,
                agentKind: agentKind,
                stage: "association_read",
                reasonCode: "no_canonical_association",
                retryable: true
            )
            return ProvenanceWorkspaceCodingAgentSessionAssociationResponse(
                found: false,
                reason: "no_canonical_association",
                workspaceID: workspaceID,
                agentKind: agentKind,
                association: nil,
                readiness: readiness
            )
        }

        let status: ProvenanceWorkspaceCodingAgentSessionReadinessStatus = association.promptObservedAt == nil
            ? .agentDetectedAwaitingFirstPrompt
            : .associationEstablishedProjectionPending
        let readiness = readiness(association: association, status: status)
        return ProvenanceWorkspaceCodingAgentSessionAssociationResponse(
            found: true,
            workspaceID: workspaceID,
            agentKind: agentKind,
            association: association,
            readiness: readiness
        )
    }

    func upsertWorkspaceCodingAgentSessionAssociation(
        _ association: ProvenanceWorkspaceCodingAgentSessionAssociationRecord,
        event: ProvenanceEvent,
        latestEventSequence: Int?
    ) throws {
        let latestSequence = association.latestEventSequence ?? latestEventSequence
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_workspace_coding_agent_session_associations (
                id,
                workspace_id,
                session_id,
                agent_kind,
                raw_session_id,
                canonical_session_id,
                surface_id,
                repository_id,
                worktree_id,
                current_directory,
                source_path,
                stage,
                reason_code,
                retryable,
                first_observed_at_seconds,
                prompt_observed_at_seconds,
                last_observed_at_seconds,
                last_transition_at_seconds,
                latest_event_id,
                latest_event_sequence
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                workspace_id = excluded.workspace_id,
                session_id = excluded.session_id,
                agent_kind = excluded.agent_kind,
                raw_session_id = COALESCE(excluded.raw_session_id, raw_session_id),
                canonical_session_id = excluded.canonical_session_id,
                surface_id = COALESCE(excluded.surface_id, surface_id),
                repository_id = COALESCE(excluded.repository_id, repository_id),
                worktree_id = COALESCE(excluded.worktree_id, worktree_id),
                current_directory = COALESCE(excluded.current_directory, current_directory),
                source_path = excluded.source_path,
                stage = excluded.stage,
                reason_code = excluded.reason_code,
                retryable = excluded.retryable,
                first_observed_at_seconds = MIN(first_observed_at_seconds, excluded.first_observed_at_seconds),
                prompt_observed_at_seconds = CASE
                    WHEN prompt_observed_at_seconds IS NULL THEN excluded.prompt_observed_at_seconds
                    WHEN excluded.prompt_observed_at_seconds IS NULL THEN prompt_observed_at_seconds
                    ELSE MAX(prompt_observed_at_seconds, excluded.prompt_observed_at_seconds)
                END,
                last_observed_at_seconds = MAX(last_observed_at_seconds, excluded.last_observed_at_seconds),
                last_transition_at_seconds = MAX(last_transition_at_seconds, excluded.last_transition_at_seconds),
                latest_event_id = CASE
                    WHEN excluded.latest_event_sequence IS NOT NULL
                     AND (latest_event_sequence IS NULL OR excluded.latest_event_sequence >= latest_event_sequence)
                    THEN excluded.latest_event_id
                    ELSE latest_event_id
                END,
                latest_event_sequence = CASE
                    WHEN excluded.latest_event_sequence IS NOT NULL
                     AND (latest_event_sequence IS NULL OR excluded.latest_event_sequence >= latest_event_sequence)
                    THEN excluded.latest_event_sequence
                    ELSE latest_event_sequence
                END
            """
        )
        defer { upsert.finalize() }

        try upsert.bind(association.id, at: 1)
        try upsert.bind(association.workspaceID, at: 2)
        try upsert.bind(association.sessionID, at: 3)
        try upsert.bind(association.agentKind, at: 4)
        try upsert.bind(association.rawSessionID, at: 5)
        try upsert.bind(association.canonicalSessionID, at: 6)
        try upsert.bind(association.surfaceID, at: 7)
        try upsert.bind(association.repositoryID, at: 8)
        try upsert.bind(association.worktreeID, at: 9)
        try upsert.bind(association.currentDirectory, at: 10)
        try upsert.bind(association.sourcePath, at: 11)
        try upsert.bind(association.stage, at: 12)
        try upsert.bind(association.reasonCode, at: 13)
        try upsert.bind(association.retryable ? 1 : 0, at: 14)
        try upsert.bind(association.firstObservedAt.timeIntervalSince1970, at: 15)
        try upsert.bind(association.promptObservedAt?.timeIntervalSince1970, at: 16)
        try upsert.bind(association.lastObservedAt.timeIntervalSince1970, at: 17)
        try upsert.bind(association.lastTransitionAt.timeIntervalSince1970, at: 18)
        try upsert.bind(association.latestEventID ?? event.id, at: 19)
        if let latestSequence {
            try upsert.bind(latestSequence, at: 20)
        } else {
            try upsert.bind(nil as String?, at: 20)
        }

        _ = try upsert.step()
    }

    private func workspaceCodingAgentSessionAssociation(
        workspaceID: String,
        agentKind: String
    ) throws -> ProvenanceWorkspaceCodingAgentSessionAssociationRecord? {
        let query = try database.prepare(
            """
            SELECT
                id,
                workspace_id,
                session_id,
                agent_kind,
                raw_session_id,
                canonical_session_id,
                surface_id,
                repository_id,
                worktree_id,
                current_directory,
                source_path,
                stage,
                reason_code,
                retryable,
                first_observed_at_seconds,
                prompt_observed_at_seconds,
                last_observed_at_seconds,
                last_transition_at_seconds,
                latest_event_id,
                latest_event_sequence
            FROM provenance_workspace_coding_agent_session_associations
            WHERE workspace_id = ?
              AND agent_kind = ?
            ORDER BY
                CASE
                    WHEN source_path = 'display' THEN 1
                    ELSE 0
                END ASC,
                prompt_observed_at_seconds IS NULL ASC,
                CASE source_path
                    WHEN 'transcript' THEN 0
                    WHEN 'hook' THEN 1
                    WHEN 'lifecycle' THEN 2
                    WHEN 'sidecar' THEN 3
                    WHEN 'replay' THEN 4
                    ELSE 5
                END ASC,
                prompt_observed_at_seconds DESC,
                last_observed_at_seconds DESC,
                latest_event_sequence DESC,
                rowid DESC
            LIMIT 1
            """
        )
        defer { query.finalize() }

        try query.bind(workspaceID, at: 1)
        try query.bind(agentKind, at: 2)
        guard try query.step() else { return nil }
        return workspaceCodingAgentSessionAssociation(from: query)
    }

    private func workspaceCodingAgentSessionAssociation(
        from query: ProvenanceSQLiteStatement
    ) -> ProvenanceWorkspaceCodingAgentSessionAssociationRecord? {
        guard let id = query.string(at: 0),
              let workspaceID = query.string(at: 1),
              let sessionID = query.string(at: 2),
              let agentKind = query.string(at: 3),
              let canonicalSessionID = query.string(at: 5),
              let sourcePath = query.string(at: 10),
              let stage = query.string(at: 11) else {
            return nil
        }

        return ProvenanceWorkspaceCodingAgentSessionAssociationRecord(
            id: id,
            workspaceID: workspaceID,
            sessionID: sessionID,
            agentKind: agentKind,
            rawSessionID: query.string(at: 4),
            canonicalSessionID: canonicalSessionID,
            surfaceID: query.string(at: 6),
            repositoryID: query.string(at: 7),
            worktreeID: query.string(at: 8),
            currentDirectory: query.string(at: 9),
            sourcePath: sourcePath,
            stage: stage,
            reasonCode: query.string(at: 12),
            retryable: query.int(at: 13) != 0,
            firstObservedAt: Date(timeIntervalSince1970: query.double(at: 14) ?? 0),
            promptObservedAt: query.double(at: 15).map { Date(timeIntervalSince1970: $0) },
            lastObservedAt: Date(timeIntervalSince1970: query.double(at: 16) ?? 0),
            lastTransitionAt: Date(timeIntervalSince1970: query.double(at: 17) ?? 0),
            latestEventID: query.string(at: 18),
            latestEventSequence: query.optionalInt(at: 19)
        )
    }

    private func readiness(
        association: ProvenanceWorkspaceCodingAgentSessionAssociationRecord,
        status: ProvenanceWorkspaceCodingAgentSessionReadinessStatus
    ) -> ProvenanceWorkspaceCodingAgentSessionReadiness {
        ProvenanceWorkspaceCodingAgentSessionReadiness(
            status: status,
            workspaceID: association.workspaceID,
            agentKind: association.agentKind,
            sessionID: association.sessionID,
            rawSessionID: association.rawSessionID,
            canonicalSessionID: association.canonicalSessionID,
            sourcePath: association.sourcePath,
            stage: association.stage,
            reasonCode: association.reasonCode,
            retryable: association.retryable,
            firstObservedAt: association.firstObservedAt,
            promptObservedAt: association.promptObservedAt,
            lastTransitionAt: association.lastTransitionAt,
            latestEventID: association.latestEventID,
            latestEventSequence: association.latestEventSequence
        )
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
