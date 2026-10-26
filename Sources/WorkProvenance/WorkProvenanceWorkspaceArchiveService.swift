import Foundation
import ProvenanceEngineContracts

/// Reads Explorer history facts and captures display metadata at workspace close.
actor WorkProvenanceWorkspaceArchiveService {
    private let client: any ProvenanceEngineClient

    init(client: any ProvenanceEngineClient) {
        self.client = client
    }

    /// Reads every retained archive page without imposing a UI-sized history cap.
    func archivedWorkspaces() async throws -> [ProvenanceArchivedWorkspaceRecord] {
        var records: [ProvenanceArchivedWorkspaceRecord] = []
        var cursor: String?
        var seenCursors: Set<String> = []
        repeat {
            try Task.checkCancellation()
            let page = try await client.archivedWorkspaces(.init(limit: 500, cursor: cursor))
            records.append(contentsOf: page.records)
            cursor = page.nextCursor
            if let cursor, !seenCursors.insert(cursor).inserted {
                throw WorkspaceArchivePaginationError.repeatedCursor
            }
        } while cursor != nil
        return records
    }

    /// Reads every retained workspace identity with observed session evidence.
    func workspacesWithSessions() async throws -> [ProvenanceWorkspaceHistorySummary] {
        var workspaces: [ProvenanceWorkspaceHistorySummary] = []
        var cursor: String?
        var seenCursors: Set<String> = []
        repeat {
            try Task.checkCancellation()
            let page = try await client.workspaceHistory(.init(limit: 500, cursor: cursor))
            workspaces.append(contentsOf: page.workspaces)
            cursor = page.nextCursor
            if let cursor, !seenCursors.insert(cursor).inserted {
                throw WorkspaceArchivePaginationError.repeatedCursor
            }
        } while cursor != nil
        return workspaces
    }

    /// Resolves stable repository identities to names already recorded by Provenance Engine.
    func repositoryNames(for repositoryIDs: Set<String>) async throws -> [String: String] {
        var names: [String: String] = [:]
        for repositoryID in repositoryIDs.sorted() {
            try Task.checkCancellation()
            guard let repository = try await client.worktrees(.init(
                repositoryID: repositoryID, limit: 1)).worktrees.first?.repository else { continue }
            let slugName = repository.remoteSlug?.split(separator: "/").last.map(String.init)
            let pathName = URL(fileURLWithPath: repository.path).lastPathComponent
            let name = slugName.flatMap { $0.isEmpty ? nil : $0 } ?? pathName
            if !name.isEmpty { names[repositoryID] = name }
        }
        return names
    }

    func workspaceSessions(
        stableWorkspaceID: UUID,
        limit: Int = 50,
        cursor: String? = nil
    ) async throws -> ProvenanceWorkspaceSessionPageResponse {
        try await client.workspaceSessions(.init(
            workspaceID: stableWorkspaceID.uuidString,
            limit: limit,
            cursor: cursor
        ))
    }

    func sessionEvidence(sessionID: String) async throws -> (
        ProvenanceFactualSessionProjectionResponse, ProvenanceSessionOutcomeResponse
    ) {
        async let projection = client.factualSessionProjection(.init(sessionID: sessionID))
        async let outcome = client.sessionOutcome(.init(sessionID: sessionID))
        return try await (projection, outcome)
    }

    func liveFacts(stableWorkspaceID: UUID) async throws
        -> (display: ProvenanceWorkspaceDisplayRecord?, lastActivityAt: Date?) {
        let workspaceID = stableWorkspaceID.uuidString
        async let displayResponse = client.workspaceDisplay(.init(workspaceID: workspaceID))
        async let sessionResponse = client.workspaceSessions(.init(workspaceID: workspaceID, limit: 1))
        let display = try await displayResponse.display
        let sessionActivity = try await sessionResponse.sessions.first?.lastActivityAt
        return (display, [display?.lastSubmittedPromptSubmittedAt, sessionActivity].compactMap { $0 }.max())
    }

    func clearExplorerHistory(at timestamp: Date = Date()) async throws {
        try await client.clearArchivedWorkspaces(at: timestamp)
    }

    /// Repairs absent or older close events when the latest restore snapshot reached disk first.
    func recoverClosures(_ candidates: [WorkspaceArchiveRecoveryCandidate]) async throws {
        guard !candidates.isEmpty else { return }
        _ = try await recoverClosures(candidates, existing: archivedWorkspaces())
    }

    /// Reuses the archive read from an Explorer refresh; a second read is needed only after a repair.
    func recoverClosures(_ candidates: [WorkspaceArchiveRecoveryCandidate],
                         existing records: [ProvenanceArchivedWorkspaceRecord]) async throws -> Bool {
        let existing = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        var repaired = false
        for candidate in candidates where existing[candidate.stableID.uuidString]
            .map({ $0.closedAt < candidate.closedAt }) ?? true {
            try Task.checkCancellation()
            try await client.recordArchivedWorkspace(ProvenanceArchivedWorkspaceRecord(
                id: candidate.stableID.uuidString,
                title: candidate.title,
                createdAt: nil,
                closedAt: candidate.closedAt,
                lastActivityAt: nil,
                displayAtClose: nil,
                colorHex: candidate.colorHex,
                coverageCode: "close_snapshot_recovery"
            ))
            repaired = true
        }
        return repaired
    }

    func recordClosure(
        stableWorkspaceID: UUID,
        title: String,
        createdAt: Date,
        closedAt: Date,
        colorHex: String?,
        lastRecordedStatusCode: String?
    ) async throws {
        let display: ProvenanceWorkspaceDisplayRecord?
        do {
            display = try await client.workspaceDisplay(.init(workspaceID: stableWorkspaceID.uuidString)).display
        } catch {
            // A display query failure must not prevent the identity from being archived.
            StartupBreadcrumbLog.append("workspace_archive_display_read_failed", fields: [
                "workspace_id": stableWorkspaceID.uuidString,
                "error_type": String(reflecting: type(of: error)),
            ])
            display = nil
        }
        let sessionActivity: Date?
        do {
            sessionActivity = try await client.workspaceSessions(.init(
                workspaceID: stableWorkspaceID.uuidString, limit: 1
            )).sessions.first?.lastActivityAt
        } catch {
            StartupBreadcrumbLog.append("workspace_archive_session_read_failed", fields: [
                "workspace_id": stableWorkspaceID.uuidString,
                "error_type": String(reflecting: type(of: error)),
            ])
            sessionActivity = nil
        }
        let record = ProvenanceArchivedWorkspaceRecord(
            id: stableWorkspaceID.uuidString,
            title: title,
            createdAt: createdAt,
            closedAt: closedAt,
            lastActivityAt: [display?.lastSubmittedPromptSubmittedAt, sessionActivity]
                .compactMap { $0 }.max(),
            displayAtClose: display,
            colorHex: colorHex,
            coverageCode: nil,
            lastRecordedStatusCode: lastRecordedStatusCode
        )
        try await client.recordArchivedWorkspace(record)
    }
}

private enum WorkspaceArchivePaginationError: Error {
    case repeatedCursor
}
