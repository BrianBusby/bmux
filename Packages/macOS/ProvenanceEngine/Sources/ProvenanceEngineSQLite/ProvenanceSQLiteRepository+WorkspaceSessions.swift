import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func workspaceSessionPage(_ request: ProvenanceWorkspaceSessionPageRequest) throws
        -> ProvenanceWorkspaceSessionPageResponse {
        let workspaceID = request.workspaceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !workspaceID.isEmpty, workspaceID == request.workspaceID else {
            throw ProvenanceSQLiteError.sqlite(message: "invalid workspace session ID")
        }
        let cursor: (Double, String)?
        if let raw = request.cursor {
            let parts = raw.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, let bits = UInt64(parts[0], radix: 16),
                  !parts[1].isEmpty, Double(bitPattern: bits).isFinite else {
                throw ProvenanceSQLiteError.sqlite(message: "invalid workspace session cursor")
            }
            cursor = (Double(bitPattern: bits), String(parts[1]))
        } else {
            cursor = nil
        }
        let limit = min(500, max(1, request.limit))
        let query = try database.prepare("""
            WITH linked_ids AS (
                SELECT id FROM provenance_sessions WHERE workspace_id = ?
                UNION
                SELECT canonical_session_id
                FROM provenance_workspace_coding_agent_session_associations
                WHERE workspace_id = ?
            ), linked AS (
                SELECT s.* FROM provenance_sessions s
                JOIN linked_ids ON linked_ids.id = s.id
            ), ordered AS (
                SELECT linked.*,
                    MAX(
                        COALESCE(linked.started_at_seconds, 0),
                        COALESCE((SELECT MAX(p.submitted_at_seconds)
                                  FROM provenance_coding_agent_prompts p
                                  WHERE p.session_id = linked.id), 0),
                        COALESCE((SELECT MAX(COALESCE(t.completed_at_seconds, t.started_at_seconds))
                                  FROM provenance_coding_agent_turns t
                                  WHERE t.session_id = linked.id), 0)
                    ) AS activity_at_seconds,
                    COUNT(*) OVER() AS total_count
                FROM linked
            )
            SELECT id, agent_kind, workspace_id, surface_id, worktree_id, cwd,
                   status, started_at_seconds, updated_at_seconds, activity_at_seconds, total_count
            FROM ordered
            WHERE (? IS NULL OR activity_at_seconds < ?
                   OR (activity_at_seconds = ? AND id < ?))
            ORDER BY activity_at_seconds DESC, id DESC
            LIMIT ?
            """)
        defer { query.finalize() }
        try query.bind(workspaceID, at: 1)
        try query.bind(workspaceID, at: 2)
        try query.bind(cursor.map { String($0.0) }, at: 3)
        try query.bind(cursor?.0, at: 4)
        try query.bind(cursor?.0, at: 5)
        try query.bind(cursor?.1, at: 6)
        try query.bind(limit + 1, at: 7)
        var sessions: [ProvenanceWorkspaceSessionSummary] = []
        var lastKey: (Double, String)?
        var totalCount = 0
        while try query.step() {
            guard let id = query.string(at: 0), let agentKind = query.string(at: 1),
                  let status = query.string(at: 6), let updatedAt = query.double(at: 8),
                  let activity = query.double(at: 9) else {
                throw ProvenanceSQLiteError.sqlite(message: "invalid workspace session row")
            }
            totalCount = query.int(at: 10)
            if sessions.count == limit {
                let next = lastKey.map { "\(String($0.0.bitPattern, radix: 16))|\($0.1)" }
                return ProvenanceWorkspaceSessionPageResponse(
                    workspaceID: workspaceID, sessions: sessions, nextCursor: next,
                    totalCount: totalCount
                )
            }
            let session = ProvenanceSessionRecord(
                id: id, agentKind: agentKind, workspaceID: query.string(at: 2),
                surfaceID: query.string(at: 3), worktreeID: query.string(at: 4),
                cwd: query.string(at: 5), status: status,
                startedAt: query.double(at: 7).map(Date.init(timeIntervalSince1970:)),
                updatedAt: Date(timeIntervalSince1970: updatedAt)
            )
            sessions.append(.init(
                session: session,
                lastActivityAt: activity > 0 ? Date(timeIntervalSince1970: activity) : nil
            ))
            lastKey = (activity, id)
        }
        return ProvenanceWorkspaceSessionPageResponse(
            workspaceID: workspaceID, sessions: sessions, nextCursor: nil,
            totalCount: totalCount
        )
    }
}
