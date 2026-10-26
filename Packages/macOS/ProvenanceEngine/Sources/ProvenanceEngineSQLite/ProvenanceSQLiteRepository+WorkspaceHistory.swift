import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    private static var workspaceHistoryCTE: String {
        """
            WITH linked AS (
                SELECT workspace_id, id AS session_id
                FROM provenance_sessions WHERE workspace_id IS NOT NULL
                UNION
                SELECT workspace_id, canonical_session_id
                FROM provenance_workspace_coding_agent_session_associations
            ), session_activity AS (
                SELECT linked.workspace_id, s.started_at_seconds, s.cwd, s.worktree_id,
                    \(Self.sessionActivitySQL) AS activity_at_seconds
                FROM linked JOIN provenance_sessions s ON s.id = linked.session_id
            ), history AS (
                SELECT workspace_id, MIN(started_at_seconds) AS first_session_at_seconds,
                    MAX(activity_at_seconds) AS activity_at_seconds, COUNT(*) AS session_count
                FROM session_activity
                GROUP BY workspace_id
            )
        """
    }

    func workspaceHistoryPage(_ request: ProvenanceWorkspaceHistoryPageRequest) throws
        -> ProvenanceWorkspaceHistoryPageResponse {
        let cursor: (Double, String)?
        if let raw = request.cursor {
            let parts = raw.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, let bits = UInt64(parts[0], radix: 16),
                  !parts[1].isEmpty, Double(bitPattern: bits).isFinite else {
                throw ProvenanceSQLiteError.sqlite(message: "invalid workspace history cursor")
            }
            cursor = (Double(bitPattern: bits), String(parts[1]))
        } else {
            cursor = nil
        }
        let limit = min(500, max(1, request.limit))
        let clearedAt = try latestArchiveClearAt()?.timeIntervalSince1970
        let query = try database.prepare("""
            \(Self.workspaceHistoryCTE)
            SELECT workspace_id, first_session_at_seconds, activity_at_seconds, session_count,
                (SELECT cwd FROM session_activity
                 WHERE session_activity.workspace_id = history.workspace_id AND cwd IS NOT NULL
                 ORDER BY activity_at_seconds DESC LIMIT 1),
                (SELECT w.repository_id FROM session_activity a
                 JOIN provenance_worktrees w ON w.id = a.worktree_id
                 WHERE a.workspace_id = history.workspace_id
                 ORDER BY a.activity_at_seconds DESC LIMIT 1)
            FROM history
            WHERE (? IS NULL OR activity_at_seconds > ?)
              AND (? IS NULL OR activity_at_seconds < ?
                   OR (activity_at_seconds = ? AND workspace_id < ?))
            ORDER BY activity_at_seconds DESC, workspace_id DESC
            LIMIT ?
            """)
        defer { query.finalize() }
        try query.bind(clearedAt, at: 1)
        try query.bind(clearedAt, at: 2)
        try query.bind(cursor.map { String($0.0) }, at: 3)
        try query.bind(cursor?.0, at: 4)
        try query.bind(cursor?.0, at: 5)
        try query.bind(cursor?.1, at: 6)
        try query.bind(limit + 1, at: 7)
        var workspaces: [ProvenanceWorkspaceHistorySummary] = []
        var lastKey: (Double, String)?
        while try query.step() {
            guard let id = query.string(at: 0), let activity = query.double(at: 2) else {
                throw ProvenanceSQLiteError.sqlite(message: "invalid workspace history row")
            }
            if workspaces.count == limit {
                let next = lastKey.map { "\(String($0.0.bitPattern, radix: 16))|\($0.1)" }
                return ProvenanceWorkspaceHistoryPageResponse(workspaces: workspaces, nextCursor: next)
            }
            workspaces.append(ProvenanceWorkspaceHistorySummary(
                id: id,
                firstSessionAt: query.double(at: 1).map(Date.init(timeIntervalSince1970:)),
                lastActivityAt: activity > 0 ? Date(timeIntervalSince1970: activity) : nil,
                sessionCount: query.int(at: 3),
                lastKnownDirectory: query.string(at: 4),
                lastKnownRepositoryID: query.string(at: 5),
                display: try workspaceDisplay(.init(workspaceID: id)).display
            ))
            lastKey = (activity, id)
        }
        return ProvenanceWorkspaceHistoryPageResponse(workspaces: workspaces, nextCursor: nil)
    }

    func workspaceHistoryFilterFacets() throws -> ProvenanceWorkspaceHistoryFacetsResponse {
        let clearedAt = try latestArchiveClearAt()?.timeIntervalSince1970
        let query = try database.prepare("""
            \(Self.workspaceHistoryCTE)
            SELECT history.workspace_id, history.activity_at_seconds,
                COALESCE(display.repository_id,
                    (SELECT w.repository_id FROM session_activity a
                     JOIN provenance_worktrees w ON w.id = a.worktree_id
                     WHERE a.workspace_id = history.workspace_id
                     ORDER BY a.activity_at_seconds DESC LIMIT 1)),
                display.project_links_json, display.pull_request_owner_login
            FROM history
            LEFT JOIN provenance_workspace_display display
                ON display.workspace_id = history.workspace_id
            WHERE (? IS NULL OR history.activity_at_seconds > ?)
            ORDER BY history.activity_at_seconds DESC, history.workspace_id DESC
            """)
        defer { query.finalize() }
        try query.bind(clearedAt, at: 1)
        try query.bind(clearedAt, at: 2)
        var facets: [ProvenanceWorkspaceHistoryFacet] = []
        while try query.step() {
            guard let id = query.string(at: 0), let activity = query.double(at: 1) else {
                throw ProvenanceSQLiteError.sqlite(message: "invalid workspace history facet row")
            }
            let links = try JSONDecoder().decode([ProvenanceWorkspaceDisplayProjectLinkRecord].self,
                from: Data((query.string(at: 3) ?? "[]").utf8))
            facets.append(ProvenanceWorkspaceHistoryFacet(workspaceID: id,
                lastActivityAt: activity > 0 ? Date(timeIntervalSince1970: activity) : nil,
                repositoryID: query.string(at: 2), projectLinks: links,
                pullRequestOwnerLogin: query.string(at: 4)))
        }
        return ProvenanceWorkspaceHistoryFacetsResponse(facets: facets)
    }
}
