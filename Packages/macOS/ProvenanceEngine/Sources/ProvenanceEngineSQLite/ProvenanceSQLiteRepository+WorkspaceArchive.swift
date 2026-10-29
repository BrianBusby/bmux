import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func persistArchivedWorkspace(_ record: ProvenanceArchivedWorkspaceRecord) throws {
        let workspaceID = record.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !workspaceID.isEmpty,
              workspaceID == record.id,
              record.displayAtClose?.workspaceID == nil || record.displayAtClose?.workspaceID == workspaceID,
              record.closedAt.timeIntervalSince1970.isFinite else {
            throw ProvenanceSQLiteError.sqlite(message: "invalid archived workspace record")
        }
        if let clearedAt = try latestArchiveClearAt(), record.closedAt <= clearedAt {
            return
        }
        let previous = try archivedWorkspace(id: workspaceID)
        // The enclosing immediate transaction serializes writers. A later
        // identity-only write for the same close must not erase recorded facts.
        let incomingIdentityOnly = record.createdAt == nil && record.lastActivityAt == nil &&
            record.displayAtClose == nil && record.lastRecordedStatusCode == nil
        let previousIdentityOnly = previous.map {
            $0.createdAt == nil && $0.lastActivityAt == nil &&
                $0.displayAtClose == nil && $0.lastRecordedStatusCode == nil
        } ?? false
        if let previous, previous.closedAt == record.closedAt,
           incomingIdentityOnly && !previousIdentityOnly {
            return
        }
        let earliestCreation = [previous?.createdAt, record.createdAt].compactMap { $0 }.min()
        let latestActivity = [previous?.lastActivityAt, record.lastActivityAt].compactMap { $0 }.max()
        let retained = ProvenanceArchivedWorkspaceRecord(
            id: workspaceID,
            title: record.title,
            createdAt: earliestCreation,
            closedAt: record.closedAt,
            lastActivityAt: latestActivity,
            displayAtClose: record.displayAtClose,
            colorHex: record.colorHex,
            coverageCode: previousIdentityOnly && !incomingIdentityOnly
                ? record.coverageCode
                : (record.coverageCode ?? previous?.coverageCode),
            lastRecordedStatusCode: record.lastRecordedStatusCode
        )
        let json = try payloadEncoder.encode(retained)
        guard let jsonString = String(data: json, encoding: .utf8) else {
            throw ProvenanceSQLiteError.sqlite(message: "archived workspace encoding is not UTF-8")
        }
        let statement = try database.prepare("""
            INSERT INTO provenance_archived_workspaces (workspace_id, closed_at_seconds, record_json)
            VALUES (?, ?, ?)
            ON CONFLICT(workspace_id) DO UPDATE SET
                closed_at_seconds = excluded.closed_at_seconds,
                record_json = excluded.record_json
            WHERE excluded.closed_at_seconds >= provenance_archived_workspaces.closed_at_seconds
            """)
        defer { statement.finalize() }
        try statement.bind(workspaceID, at: 1)
        try statement.bind(record.closedAt.timeIntervalSince1970, at: 2)
        try statement.bind(jsonString, at: 3)
        _ = try statement.step()
    }

    func latestArchiveClearAt() throws -> Date? {
        let statement = try database.prepare("SELECT value FROM provenance_metadata WHERE key = 'workspace_archive_cleared_at'")
        defer { statement.finalize() }
        guard try statement.step() else { return nil }
        guard let raw = statement.string(at: 0),
              let bits = UInt64(raw, radix: 16),
              Double(bitPattern: bits).isFinite else {
            throw ProvenanceSQLiteError.sqlite(message: "invalid workspace archive clear marker")
        }
        return Date(timeIntervalSince1970: Double(bitPattern: bits))
    }

    private func archivedWorkspace(id: String) throws -> ProvenanceArchivedWorkspaceRecord? {
        let statement = try database.prepare("SELECT record_json FROM provenance_archived_workspaces WHERE workspace_id = ?")
        defer { statement.finalize() }
        try statement.bind(id, at: 1)
        guard try statement.step(), let json = statement.string(at: 0),
              let data = json.data(using: .utf8) else { return nil }
        return try payloadDecoder.decode(ProvenanceArchivedWorkspaceRecord.self, from: data)
    }

    func clearArchivedWorkspaceRecords(at timestamp: Date) throws {
        let seconds = timestamp.timeIntervalSince1970
        guard seconds.isFinite else {
            throw ProvenanceSQLiteError.sqlite(message: "invalid workspace archive clear time")
        }
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let previous = try latestArchiveClearAt()
            let effectiveTimestamp = max(previous ?? timestamp, timestamp)
            let statement = try database.prepare("""
                INSERT INTO provenance_metadata (key, value)
                VALUES ('workspace_archive_cleared_at', ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """)
            defer { statement.finalize() }
            try statement.bind(String(effectiveTimestamp.timeIntervalSince1970.bitPattern, radix: 16), at: 1)
            _ = try statement.step()
            try database.execute("DELETE FROM provenance_archived_workspaces")
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    func archivedWorkspacePage(_ request: ProvenanceArchivedWorkspacePageRequest) throws
        -> ProvenanceArchivedWorkspacePageResponse {
        let limit = min(500, max(1, request.limit))
        let cursor: (Double, String)?
        if let raw = request.cursor {
            let parts = raw.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let bits = UInt64(parts[0], radix: 16),
                  !parts[1].isEmpty,
                  Double(bitPattern: bits).isFinite else {
                throw ProvenanceSQLiteError.sqlite(message: "invalid archived workspace cursor")
            }
            cursor = (Double(bitPattern: bits), String(parts[1]))
        } else {
            cursor = nil
        }
        let statement = try database.prepare("""
            SELECT workspace_id, closed_at_seconds, record_json
            FROM provenance_archived_workspaces
            WHERE (? IS NULL OR closed_at_seconds < ?
                   OR (closed_at_seconds = ? AND workspace_id < ?))
            ORDER BY closed_at_seconds DESC, workspace_id DESC
            LIMIT ?
            """)
        defer { statement.finalize() }
        try statement.bind(cursor.map { String($0.0) }, at: 1)
        try statement.bind(cursor?.0, at: 2)
        try statement.bind(cursor?.0, at: 3)
        try statement.bind(cursor?.1, at: 4)
        try statement.bind(limit + 1, at: 5)
        var records: [ProvenanceArchivedWorkspaceRecord] = []
        var lastKey: (Double, String)?
        while try statement.step() {
            guard let id = statement.string(at: 0),
                  let closedAt = statement.double(at: 1),
                  let json = statement.string(at: 2),
                  let data = json.data(using: .utf8) else {
                throw ProvenanceSQLiteError.sqlite(message: "invalid archived workspace row")
            }
            if records.count == limit {
                let next = lastKey.map { "\(String($0.0.bitPattern, radix: 16))|\($0.1)" }
                return ProvenanceArchivedWorkspacePageResponse(records: records, nextCursor: next)
            }
            records.append(try payloadDecoder.decode(ProvenanceArchivedWorkspaceRecord.self, from: data))
            lastKey = (closedAt, id)
        }
        return ProvenanceArchivedWorkspacePageResponse(records: records, nextCursor: nil)
    }
}
