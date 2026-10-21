import Foundation
import ProvenanceEngineContracts

/// Captures the last PE display facts when bmux closes a logical workspace.
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

    func recordClosure(
        stableWorkspaceID: UUID,
        title: String,
        createdAt: Date,
        closedAt: Date,
        colorHex: String?
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
            coverageCode: nil
        )
        try await client.recordArchivedWorkspace(record)
    }
}

private enum WorkspaceArchivePaginationError: Error {
    case repeatedCursor
}
