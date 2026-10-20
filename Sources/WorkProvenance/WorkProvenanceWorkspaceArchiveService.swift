import Foundation
import ProvenanceEngineContracts

/// Captures the last PE display facts when bmux closes a logical workspace.
actor WorkProvenanceWorkspaceArchiveService {
    private let client: any ProvenanceEngineClient

    init(client: any ProvenanceEngineClient) {
        self.client = client
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
