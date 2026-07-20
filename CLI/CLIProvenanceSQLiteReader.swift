import Foundation
import SQLite3

final class CLIProvenanceSQLiteReader {
    private var handle: OpaquePointer?

    init(databaseURL: URL) throws {
        var opened: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &opened, flags, nil) == SQLITE_OK, let opened else {
            let message = opened.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "open failed"
            if let opened {
                sqlite3_close(opened)
            }
            throw CLIError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.error.openDatabaseFailed",
                    defaultValue: "failed to open provenance database: %@"
                ),
                message
            ))
        }
        self.handle = opened
    }

    deinit {
        if let handle {
            sqlite3_close(handle)
        }
    }

    func explain(target: CLIProvenanceResolvedTarget) throws -> CLIProvenanceExplanation {
        guard let worktree = try worktree(path: target.repositoryRoot) else {
            return CLIProvenanceExplanation(
                requestedPath: target.requestedPath,
                repositoryPath: target.repositoryRoot,
                relativePath: target.relativePath,
                found: false,
                reason: String(localized: "cli.provenance.reason.noWorktree", defaultValue: "no provenance has been recorded for this Git worktree"),
                fileStatus: nil,
                attributionSource: nil,
                attributionConfidence: nil,
                updatedAt: nil,
                worktree: ["path": target.repositoryRoot],
                repository: ["path": target.repositoryRoot],
                changeSet: nil,
                checkpoint: nil,
                contribution: nil,
                session: nil,
                workItem: nil
            )
        }

        guard let row = try explanationRow(worktreeID: worktree.id, relativePath: target.relativePath) else {
            return CLIProvenanceExplanation(
                requestedPath: target.requestedPath,
                repositoryPath: target.repositoryRoot,
                relativePath: target.relativePath,
                found: false,
                reason: String(localized: "cli.provenance.reason.noFile", defaultValue: "no file-level provenance has been recorded for this path"),
                fileStatus: nil,
                attributionSource: nil,
                attributionConfidence: nil,
                updatedAt: nil,
                worktree: worktree.payload,
                repository: worktree.repositoryPayload,
                changeSet: nil,
                checkpoint: nil,
                contribution: nil,
                session: nil,
                workItem: nil
            )
        }

        return CLIProvenanceExplanation(
            requestedPath: target.requestedPath,
            repositoryPath: target.repositoryRoot,
            relativePath: target.relativePath,
            found: true,
            reason: nil,
            fileStatus: row.fileStatus,
            attributionSource: row.attributionSource,
            attributionConfidence: row.attributionConfidence,
            updatedAt: row.updatedAt,
            worktree: row.worktree,
            repository: row.repository,
            changeSet: row.changeSet,
            checkpoint: row.checkpoint,
            contribution: row.contribution,
            session: row.session,
            workItem: row.workItem
        )
    }

    func context(target: CLIProvenanceResolvedTarget) throws -> CLIProvenanceContext {
        guard let worktree = try worktree(path: target.repositoryRoot) else {
            return CLIProvenanceContext(
                found: false,
                reason: String(localized: "cli.provenance.reason.noWorktree", defaultValue: "no provenance has been recorded for this Git worktree"),
                repositoryPath: target.repositoryRoot,
                worktree: ["path": target.repositoryRoot],
                repository: ["path": target.repositoryRoot],
                activeSessions: [],
                dirtyFiles: [],
                unattributedChanges: [],
                recentCheckpoints: [],
                validationRuns: [],
                conflicts: []
            )
        }

        return CLIProvenanceContext(
            found: true,
            reason: nil,
            repositoryPath: target.repositoryRoot,
            worktree: worktree.payload,
            repository: worktree.repositoryPayload,
            activeSessions: try activeSessionRows(worktreeID: worktree.id, limit: 10),
            dirtyFiles: try fileChangeRows(worktreeID: worktree.id, unattributedOnly: false, limit: 25),
            unattributedChanges: try fileChangeRows(worktreeID: worktree.id, unattributedOnly: true, limit: 15),
            recentCheckpoints: try checkpointRows(worktreeID: worktree.id, limit: 5),
            validationRuns: try validationRunRows(worktreeID: worktree.id, limit: 5),
            conflicts: try conflictRows(worktreeID: worktree.id, limit: 10)
        )
    }

    func worktreeList() throws -> CLIProvenanceWorktreeList {
        let statement = try prepare(
            """
            SELECT wt.id, wt.repository_id, wt.path, wt.branch, wt.current_head,
                   wt.is_dirty, wt.status, wt.last_reconciled_at, wt.updated_at,
                   r.id, r.path, r.remote_slug
            FROM worktrees wt
            LEFT JOIN repositories r ON r.id = wt.repository_id
            ORDER BY wt.updated_at DESC, wt.rowid DESC
            """
        )
        defer { sqlite3_finalize(statement) }
        var rows: [CLIProvenanceWorktreeRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let row = worktreeRow(from: statement) {
                rows.append(row)
            }
        }
        return CLIProvenanceWorktreeList(worktrees: rows)
    }

    func sessionTree(rootSessionID: String) throws -> CLIProvenanceSessionTree {
        let sessions = try sessionTreeSessionRows(rootSessionID: rootSessionID, limit: 100)
        let relationships = try sessionTreeRelationshipRows(rootSessionID: rootSessionID, limit: 100)
        let identities = try sessionTreeExternalIdentityRows(rootSessionID: rootSessionID, limit: 200)
        return CLIProvenanceSessionTree(
            rootSessionID: rootSessionID,
            found: !sessions.isEmpty || !relationships.isEmpty,
            reason: sessions.isEmpty && relationships.isEmpty
                ? String(localized: "cli.provenance.reason.noSession", defaultValue: "no provenance has been recorded for this session")
                : nil,
            sessions: sessions,
            relationships: relationships,
            externalIdentities: identities
        )
    }

    private func worktree(path: String) throws -> CLIProvenanceWorktreeRow? {
        let statement = try prepare(
            """
            SELECT wt.id, wt.repository_id, wt.path, wt.branch, wt.current_head,
                   wt.is_dirty, wt.status, wt.last_reconciled_at, wt.updated_at,
                   r.id, r.path, r.remote_slug
            FROM worktrees wt
            LEFT JOIN repositories r ON r.id = wt.repository_id
            WHERE wt.path = ?
            ORDER BY wt.updated_at DESC, wt.rowid DESC
            LIMIT 1
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(path, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }
        return worktreeRow(from: statement)
    }

    private func worktreeRow(from statement: OpaquePointer) -> CLIProvenanceWorktreeRow? {
        guard let id = string(statement, 0),
              let repositoryID = string(statement, 1),
              let path = string(statement, 2) else {
            return nil
        }
        return CLIProvenanceWorktreeRow(
            id: id,
            repositoryID: repositoryID,
            path: path,
            branch: string(statement, 3),
            currentHEAD: string(statement, 4),
            isDirty: sqlite3_column_int(statement, 5) != 0,
            status: string(statement, 6),
            lastReconciledAt: double(statement, 7),
            updatedAt: double(statement, 8),
            repositoryRecordID: string(statement, 9),
            repositoryPath: string(statement, 10),
            remoteSlug: string(statement, 11)
        )
    }

    private func sessionTreeSessionRows(rootSessionID: String, limit: Int) throws -> [[String: AnyHashable]] {
        let statement = try prepare(
            """
            WITH RECURSIVE tree(session_id, tree_depth, sort_path, visited) AS (
                SELECT ?, 0, printf('%08d:%s', 0, ?), '/' || ? || '/'
                UNION ALL
                SELECT sr.session_id,
                       sr.depth,
                       tree.sort_path || '/' || printf('%08d:%s', sr.depth, sr.session_id),
                       tree.visited || sr.session_id || '/'
                FROM session_relationships sr
                JOIN tree ON sr.parent_session_id = tree.session_id
                WHERE tree.tree_depth < 50
                  AND instr(tree.visited, '/' || sr.session_id || '/') = 0
            )
            SELECT s.id, s.agent_kind, s.workspace_id, s.surface_id,
                   s.worktree_id, s.cwd, s.status, s.started_at, s.updated_at,
                   tree.tree_depth
            FROM tree
            JOIN sessions s ON s.id = tree.session_id
            ORDER BY tree.sort_path
            LIMIT ?
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(rootSessionID, to: statement, at: 1)
        try bind(rootSessionID, to: statement, at: 2)
        try bind(rootSessionID, to: statement, at: 3)
        try bind(limit, to: statement, at: 4)
        var rows: [[String: AnyHashable]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(compactPayload([
                "id": string(statement, 0),
                "agent_kind": string(statement, 1),
                "workspace_id": string(statement, 2),
                "surface_id": string(statement, 3),
                "worktree_id": string(statement, 4),
                "cwd": string(statement, 5),
                "status": string(statement, 6),
                "started_at": double(statement, 7),
                "updated_at": double(statement, 8),
                "tree_depth": int(statement, 9)
            ]))
        }
        return rows
    }

    private func sessionTreeRelationshipRows(rootSessionID: String, limit: Int) throws -> [[String: AnyHashable]] {
        let statement = try prepare(
            """
            WITH RECURSIVE tree(session_id, tree_depth, sort_path, visited) AS (
                SELECT ?, 0, printf('%08d:%s', 0, ?), '/' || ? || '/'
                UNION ALL
                SELECT sr.session_id,
                       sr.depth,
                       tree.sort_path || '/' || printf('%08d:%s', sr.depth, sr.session_id),
                       tree.visited || sr.session_id || '/'
                FROM session_relationships sr
                JOIN tree ON sr.parent_session_id = tree.session_id
                WHERE tree.tree_depth < 50
                  AND instr(tree.visited, '/' || sr.session_id || '/') = 0
            )
            SELECT sr.session_id, sr.parent_session_id, sr.root_session_id,
                   sr.inbound_delegation_id, sr.depth, sr.source, sr.confidence,
                   sr.created_at, sr.updated_at
            FROM tree
            JOIN session_relationships sr ON sr.session_id = tree.session_id
            WHERE tree.tree_depth > 0
            ORDER BY tree.sort_path
            LIMIT ?
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(rootSessionID, to: statement, at: 1)
        try bind(rootSessionID, to: statement, at: 2)
        try bind(rootSessionID, to: statement, at: 3)
        try bind(limit, to: statement, at: 4)
        var rows: [[String: AnyHashable]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(compactPayload([
                "session_id": string(statement, 0),
                "parent_session_id": string(statement, 1),
                "root_session_id": string(statement, 2),
                "inbound_delegation_id": string(statement, 3),
                "depth": int(statement, 4),
                "source": string(statement, 5),
                "confidence": string(statement, 6),
                "created_at": double(statement, 7),
                "updated_at": double(statement, 8)
            ]))
        }
        return rows
    }

    private func sessionTreeExternalIdentityRows(rootSessionID: String, limit: Int) throws -> [[String: AnyHashable]] {
        let statement = try prepare(
            """
            WITH RECURSIVE tree(session_id, tree_depth, sort_path, visited) AS (
                SELECT ?, 0, printf('%08d:%s', 0, ?), '/' || ? || '/'
                UNION ALL
                SELECT sr.session_id,
                       sr.depth,
                       tree.sort_path || '/' || printf('%08d:%s', sr.depth, sr.session_id),
                       tree.visited || sr.session_id || '/'
                FROM session_relationships sr
                JOIN tree ON sr.parent_session_id = tree.session_id
                WHERE tree.tree_depth < 50
                  AND instr(tree.visited, '/' || sr.session_id || '/') = 0
            )
            SELECT ei.id, ei.session_id, ei.system, ei.kind, ei.external_id,
                   ei.source, ei.confidence, ei.created_at, ei.updated_at
            FROM tree
            JOIN session_external_identities ei ON ei.session_id = tree.session_id
            ORDER BY tree.sort_path, ei.system, ei.kind, ei.external_id
            LIMIT ?
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(rootSessionID, to: statement, at: 1)
        try bind(rootSessionID, to: statement, at: 2)
        try bind(rootSessionID, to: statement, at: 3)
        try bind(limit, to: statement, at: 4)
        var rows: [[String: AnyHashable]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(compactPayload([
                "id": string(statement, 0),
                "session_id": string(statement, 1),
                "system": string(statement, 2),
                "kind": string(statement, 3),
                "external_id": string(statement, 4),
                "source": string(statement, 5),
                "confidence": string(statement, 6),
                "created_at": double(statement, 7),
                "updated_at": double(statement, 8)
            ]))
        }
        return rows
    }

    private func fileChangeRows(
        worktreeID: String,
        unattributedOnly: Bool,
        limit: Int
    ) throws -> [[String: AnyHashable]] {
        let sourceFilter = unattributedOnly ? "AND fc.attribution_source = 'unattributed'" : ""
        let statement = try prepare(
            """
            SELECT fc.path, fc.status, fc.attribution_source, fc.attribution_confidence,
                   fc.updated_at, fc.change_set_id,
                   cs.summary, cs.diff_fingerprint,
                   wc.id, wc.status,
                   s.id, s.agent_kind
            FROM file_changes fc
            LEFT JOIN change_sets cs ON cs.id = fc.change_set_id
            LEFT JOIN checkpoints cp ON cp.id = cs.checkpoint_id
            LEFT JOIN work_contributions wc ON wc.id = COALESCE(cs.contribution_id, cp.contribution_id)
            LEFT JOIN sessions s ON s.id = wc.session_id
            WHERE fc.worktree_id = ?
              \(sourceFilter)
              AND fc.rowid = (
                  SELECT newest.rowid
                  FROM file_changes newest
                  WHERE newest.worktree_id = fc.worktree_id
                    AND newest.path = fc.path
                  ORDER BY newest.updated_at DESC, newest.rowid DESC
                  LIMIT 1
              )
            ORDER BY fc.updated_at DESC, fc.rowid DESC
            LIMIT ?
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(worktreeID, to: statement, at: 1)
        try bind(limit, to: statement, at: 2)
        var rows: [[String: AnyHashable]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(compactPayload([
                "path": string(statement, 0),
                "status": string(statement, 1),
                "attribution_source": string(statement, 2),
                "attribution_confidence": string(statement, 3),
                "updated_at": double(statement, 4),
                "change_set_id": string(statement, 5),
                "change_set_summary": string(statement, 6),
                "diff_fingerprint": string(statement, 7),
                "contribution_id": string(statement, 8),
                "contribution_status": string(statement, 9),
                "session_id": string(statement, 10),
                "agent_kind": string(statement, 11)
            ]))
        }
        return rows
    }

    private func activeSessionRows(worktreeID: String, limit: Int) throws -> [[String: AnyHashable]] {
        let statement = try prepare(
            """
            SELECT s.id, s.agent_kind, s.workspace_id, s.surface_id,
                   s.status, s.cwd, s.started_at, s.updated_at,
                   wc.id, wc.declared_intent, wc.status,
                   wi.id, wi.title, wi.status
            FROM sessions s
            LEFT JOIN work_contributions wc
              ON wc.session_id = s.id
             AND wc.worktree_id = s.worktree_id
             AND LOWER(COALESCE(wc.status, '')) NOT IN ('complete', 'completed', 'finished', 'interrupted', 'cancelled', 'canceled', 'closed', 'stopped')
            LEFT JOIN work_items wi ON wi.id = wc.work_item_id
            WHERE s.worktree_id = ?
              AND LOWER(COALESCE(s.status, '')) NOT IN ('complete', 'completed', 'finished', 'interrupted', 'cancelled', 'canceled', 'closed', 'stopped')
            ORDER BY s.updated_at DESC, s.rowid DESC
            LIMIT ?
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(worktreeID, to: statement, at: 1)
        try bind(limit, to: statement, at: 2)
        var rows: [[String: AnyHashable]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(compactPayload([
                "id": string(statement, 0),
                "agent_kind": string(statement, 1),
                "workspace_id": string(statement, 2),
                "surface_id": string(statement, 3),
                "status": string(statement, 4),
                "cwd": string(statement, 5),
                "started_at": double(statement, 6),
                "updated_at": double(statement, 7),
                "contribution_id": string(statement, 8),
                "declared_intent": string(statement, 9),
                "contribution_status": string(statement, 10),
                "work_item_id": string(statement, 11),
                "work_item_title": string(statement, 12),
                "work_item_status": string(statement, 13)
            ]))
        }
        return rows
    }

    private func checkpointRows(worktreeID: String, limit: Int) throws -> [[String: AnyHashable]] {
        let statement = try prepare(
            """
            SELECT cp.id, cp.contribution_id, cp.sequence, cp.git_head,
                   cp.diff_fingerprint, cp.summary, cp.status,
                   cp.validation_state, cp.semantic_confidence, cp.freshness,
                   cp.created_at,
                   wc.declared_intent, wc.status,
                   s.id, s.agent_kind,
                   wi.id, wi.title
            FROM checkpoints cp
            JOIN work_contributions wc ON wc.id = cp.contribution_id
            LEFT JOIN sessions s ON s.id = wc.session_id
            LEFT JOIN work_items wi ON wi.id = wc.work_item_id
            WHERE wc.worktree_id = ?
            ORDER BY cp.created_at DESC, cp.rowid DESC
            LIMIT ?
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(worktreeID, to: statement, at: 1)
        try bind(limit, to: statement, at: 2)
        var rows: [[String: AnyHashable]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(compactPayload([
                "id": string(statement, 0),
                "contribution_id": string(statement, 1),
                "sequence": int(statement, 2),
                "git_head": string(statement, 3),
                "diff_fingerprint": string(statement, 4),
                "summary": string(statement, 5),
                "status": string(statement, 6),
                "validation_state": string(statement, 7),
                "semantic_confidence": string(statement, 8),
                "freshness": string(statement, 9),
                "created_at": double(statement, 10),
                "declared_intent": string(statement, 11),
                "contribution_status": string(statement, 12),
                "session_id": string(statement, 13),
                "agent_kind": string(statement, 14),
                "work_item_id": string(statement, 15),
                "work_item_title": string(statement, 16)
            ]))
        }
        return rows
    }

    private func validationRunRows(worktreeID: String, limit: Int) throws -> [[String: AnyHashable]] {
        let statement = try prepare(
            """
            SELECT vr.id, vr.checkpoint_id, vr.contribution_id, vr.command,
                   vr.status, vr.summary, vr.started_at, vr.ended_at,
                   cp.summary, wc.declared_intent, wc.status
            FROM validation_runs vr
            LEFT JOIN checkpoints cp ON cp.id = vr.checkpoint_id
            LEFT JOIN work_contributions wc ON wc.id = COALESCE(vr.contribution_id, cp.contribution_id)
            WHERE wc.worktree_id = ?
            ORDER BY COALESCE(vr.ended_at, vr.started_at, 0) DESC, vr.rowid DESC
            LIMIT ?
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(worktreeID, to: statement, at: 1)
        try bind(limit, to: statement, at: 2)
        var rows: [[String: AnyHashable]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(compactPayload([
                "id": string(statement, 0),
                "checkpoint_id": string(statement, 1),
                "contribution_id": string(statement, 2),
                "command": string(statement, 3),
                "status": string(statement, 4),
                "summary": string(statement, 5),
                "started_at": double(statement, 6),
                "ended_at": double(statement, 7),
                "checkpoint_summary": string(statement, 8),
                "declared_intent": string(statement, 9),
                "contribution_status": string(statement, 10)
            ]))
        }
        return rows
    }

    private func conflictRows(worktreeID: String, limit: Int) throws -> [[String: AnyHashable]] {
        let statement = try prepare(
            """
            SELECT fc.path, COUNT(DISTINCT wc.id), GROUP_CONCAT(DISTINCT wc.id),
                   MAX(fc.updated_at)
            FROM file_changes fc
            LEFT JOIN change_sets cs ON cs.id = fc.change_set_id
            LEFT JOIN checkpoints cp ON cp.id = cs.checkpoint_id
            JOIN work_contributions wc ON wc.id = COALESCE(cs.contribution_id, cp.contribution_id)
            WHERE fc.worktree_id = ?
              AND LOWER(COALESCE(wc.status, '')) NOT IN ('complete', 'completed', 'finished', 'interrupted', 'cancelled', 'canceled', 'closed', 'stopped')
            GROUP BY fc.path
            HAVING COUNT(DISTINCT wc.id) > 1
            ORDER BY MAX(fc.updated_at) DESC
            LIMIT ?
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(worktreeID, to: statement, at: 1)
        try bind(limit, to: statement, at: 2)
        var rows: [[String: AnyHashable]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(compactPayload([
                "path": string(statement, 0),
                "active_contribution_count": int(statement, 1),
                "contribution_ids": string(statement, 2),
                "updated_at": double(statement, 3)
            ]))
        }
        return rows
    }

    private func explanationRow(worktreeID: String, relativePath: String) throws -> CLIProvenanceExplanationRow? {
        let statement = try prepare(
            """
            SELECT fc.status, fc.attribution_source, fc.attribution_confidence, fc.updated_at,
                   cs.id, cs.summary, cs.diff_fingerprint, cs.created_at,
                   cp.id, cp.summary, cp.status, cp.validation_state, cp.semantic_confidence, cp.freshness, cp.created_at,
                   wc.id, wc.declared_intent, wc.status, wc.assignment_confidence, wc.updated_at,
                   s.id, s.agent_kind, s.workspace_id, s.surface_id, s.status, s.cwd, s.updated_at,
                   wi.id, wi.title, wi.status, wi.updated_at,
                   wt.id, wt.repository_id, wt.path, wt.branch, wt.current_head, wt.is_dirty, wt.status, wt.last_reconciled_at, wt.updated_at,
                   r.id, r.path, r.remote_slug
            FROM file_changes fc
            LEFT JOIN change_sets cs ON cs.id = fc.change_set_id
            LEFT JOIN checkpoints cp ON cp.id = cs.checkpoint_id
            LEFT JOIN work_contributions wc ON wc.id = COALESCE(cs.contribution_id, cp.contribution_id)
            LEFT JOIN sessions s ON s.id = wc.session_id
            LEFT JOIN work_items wi ON wi.id = wc.work_item_id
            LEFT JOIN worktrees wt ON wt.id = fc.worktree_id
            LEFT JOIN repositories r ON r.id = fc.repository_id
            WHERE fc.worktree_id = ?
              AND fc.path = ?
            ORDER BY fc.updated_at DESC, fc.rowid DESC
            LIMIT 1
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(worktreeID, to: statement, at: 1)
        try bind(relativePath, to: statement, at: 2)
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return CLIProvenanceExplanationRow(
            fileStatus: string(statement, 0),
            attributionSource: string(statement, 1),
            attributionConfidence: string(statement, 2),
            updatedAt: double(statement, 3),
            changeSet: optionalPayload([
                "id": string(statement, 4),
                "summary": string(statement, 5),
                "diff_fingerprint": string(statement, 6),
                "created_at": double(statement, 7)
            ]),
            checkpoint: optionalPayload([
                "id": string(statement, 8),
                "summary": string(statement, 9),
                "status": string(statement, 10),
                "validation_state": string(statement, 11),
                "semantic_confidence": string(statement, 12),
                "freshness": string(statement, 13),
                "created_at": double(statement, 14)
            ]),
            contribution: optionalPayload([
                "id": string(statement, 15),
                "declared_intent": string(statement, 16),
                "status": string(statement, 17),
                "assignment_confidence": string(statement, 18),
                "updated_at": double(statement, 19)
            ]),
            session: optionalPayload([
                "id": string(statement, 20),
                "agent_kind": string(statement, 21),
                "workspace_id": string(statement, 22),
                "surface_id": string(statement, 23),
                "status": string(statement, 24),
                "cwd": string(statement, 25),
                "updated_at": double(statement, 26)
            ]),
            workItem: optionalPayload([
                "id": string(statement, 27),
                "title": string(statement, 28),
                "status": string(statement, 29),
                "updated_at": double(statement, 30)
            ]),
            worktree: compactPayload([
                "id": string(statement, 31),
                "repository_id": string(statement, 32),
                "path": string(statement, 33),
                "branch": string(statement, 34),
                "current_head": string(statement, 35),
                "is_dirty": sqlite3_column_int(statement, 36) != 0,
                "status": string(statement, 37),
                "last_reconciled_at": double(statement, 38),
                "updated_at": double(statement, 39)
            ]),
            repository: compactPayload([
                "id": string(statement, 40),
                "path": string(statement, 41),
                "remote_slug": string(statement, 42)
            ])
        )
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        guard let handle else {
            throw CLIError(message: String(localized: "cli.provenance.error.databaseClosed", defaultValue: "provenance database is closed"))
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw CLIError(message: sqliteMessage)
        }
        return statement
    }

    private func bind(_ value: String, to statement: OpaquePointer, at index: Int32) throws {
        let transient = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
        guard sqlite3_bind_text(statement, index, value, -1, transient) == SQLITE_OK else {
            throw CLIError(message: sqliteMessage)
        }
    }

    private func bind(_ value: Int, to statement: OpaquePointer, at index: Int32) throws {
        guard sqlite3_bind_int(statement, index, Int32(value)) == SQLITE_OK else {
            throw CLIError(message: sqliteMessage)
        }
    }

    private func string(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard let raw = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: raw)
    }

    private func int(_ statement: OpaquePointer, _ index: Int32) -> Int? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int(statement, index))
    }

    private func double(_ statement: OpaquePointer, _ index: Int32) -> Double? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(statement, index)
    }

    private func optionalPayload(_ values: [String: AnyHashable?]) -> [String: AnyHashable]? {
        let payload = compactPayload(values)
        return payload["id"] == nil ? nil : payload
    }

    private func compactPayload(_ values: [String: AnyHashable?]) -> [String: AnyHashable] {
        values.reduce(into: [String: AnyHashable]()) { partial, item in
            if let value = item.value {
                partial[item.key] = value
            }
        }
    }

    private var sqliteMessage: String {
        guard let handle, let raw = sqlite3_errmsg(handle) else {
            return String(localized: "cli.provenance.error.unknownSQLiteError", defaultValue: "unknown sqlite error")
        }
        return String(cString: raw)
    }

}
