import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK

@main
struct ProvenanceEngineCurrentContextSeeder {
    static func main() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 4 || args.count == 5 else { throw SeedError.invalidArguments }
        let mode = args.count == 5 ? args[4] : "--full"
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: URL(fileURLWithPath: args[0]))
        let root = args[1]
        let repositoryID = args[2]
        let worktreeID = args[3]
        if mode == "--no-worktree" { return }
        let repository = ProvenanceRepositoryRecord(id: repositoryID, path: root, remoteSlug: "manaflow-ai/bmux", createdAt: date(100), updatedAt: date(160))
        let worktree = ProvenanceWorktreeRecord(id: worktreeID, repositoryID: repositoryID, path: root, branch: "provenance-extraction-phase2-contracts", currentHEAD: "abc123", isDirty: true, status: "active", lastReconciledAt: date(150), updatedAt: date(160))
        try await append(client, id: "event-context-worktree", timestamp: 160, payload: ProvenanceEventPayload(repository: repository, worktree: worktree))
        if mode == "--empty" { return }
        let workItem = ProvenanceWorkItemRecord(id: "WI-context", title: "Current context", status: "active", createdAt: date(200), updatedAt: date(200))
        try await append(client, id: "event-context-work-item", timestamp: 200, payload: ProvenanceEventPayload(workItem: workItem))
        for index in 0..<11 {
            let sessionID = String(format: "session-extra-%02d", index)
            let contributionID = String(format: "contribution-extra-%02d", index)
            let session = ProvenanceSessionRecord(id: sessionID, agentKind: "codex", workspaceID: "workspace-\(index)", surfaceID: "surface-\(index)", worktreeID: worktreeID, cwd: root, status: "active", startedAt: date(200 + Double(index)), updatedAt: date(300 + Double(index)))
            let contribution = ProvenanceContributionRecord(id: contributionID, sessionID: sessionID, worktreeID: worktreeID, workItemID: workItem.id, declaredIntent: String(format: "Intent %02d", index), status: "active", startedAt: date(200 + Double(index)), assignmentConfidence: .medium, updatedAt: date(300 + Double(index)))
            try await append(client, id: "event-context-session-\(index)", timestamp: 300 + Double(index), payload: ProvenanceEventPayload(session: session, contribution: contribution))
        }
        try await appendConflict(client, id: "conflict-a", sessionID: "session-extra-10", worktreeID: worktreeID, workItemID: workItem.id, intent: "Conflict A", timestamp: 700)
        try await appendConflict(client, id: "conflict-b", sessionID: "session-extra-09", worktreeID: worktreeID, workItemID: workItem.id, intent: "Conflict B", timestamp: 701)
        for index in 0..<7 {
            let checkpoint = ProvenanceCheckpointRecord(id: String(format: "checkpoint-context-%02d", index), contributionID: String(format: "contribution-extra-%02d", index), sequence: index, gitHEAD: String(format: "head-%02d", index), diffFingerprint: String(format: "diff-context-%02d", index), summary: String(format: "Checkpoint %02d", index), status: "in_progress", validationState: "not_run", semanticConfidence: .medium, freshness: "fresh", createdAt: date(600 + Double(index)))
            let validation = ProvenanceValidationRunRecord(id: String(format: "validation-context-%02d", index), checkpointID: checkpoint.id, command: String(format: "test-command-%02d", index), status: "passed", summary: String(format: "Validation %02d", index), startedAt: date(690 + Double(index)), endedAt: date(700 + Double(index)))
            try await append(client, id: "event-context-checkpoint-\(index)", timestamp: 700 + Double(index), payload: ProvenanceEventPayload(checkpoint: checkpoint, validationRun: validation))
        }
        for index in 0..<30 { try await appendFile(client, repositoryID: repositoryID, worktreeID: worktreeID, index: index, prefix: "dirty", pathPrefix: "Dirty", contributionID: String(format: "contribution-extra-%02d", index % 11), source: .observed, confidence: .medium, timestampBase: 400) }
        for index in 0..<18 { try await appendFile(client, repositoryID: repositoryID, worktreeID: worktreeID, index: index, prefix: "unattributed", pathPrefix: "Unattributed", contributionID: nil, source: .unattributed, confidence: .low, timestampBase: 500) }
        for index in 0..<12 {
            try await appendFile(client, repositoryID: repositoryID, worktreeID: worktreeID, index: index, prefix: "conflict-a", pathPrefix: "Conflict", contributionID: "conflict-a", source: .observed, confidence: .medium, timestampBase: 800)
            try await appendFile(client, repositoryID: repositoryID, worktreeID: worktreeID, index: index, prefix: "conflict-b", pathPrefix: "Conflict", contributionID: "conflict-b", source: .observed, confidence: .medium, timestampBase: 800.1)
        }
    }
    static func appendConflict(_ client: any ProvenanceEngineClient, id: String, sessionID: String, worktreeID: String, workItemID: String, intent: String, timestamp: Double) async throws {
        let contribution = ProvenanceContributionRecord(id: id, sessionID: sessionID, worktreeID: worktreeID, workItemID: workItemID, declaredIntent: intent, status: "active", startedAt: date(timestamp), assignmentConfidence: .medium, updatedAt: date(timestamp))
        try await append(client, id: "event-context-\(id)", timestamp: timestamp, payload: ProvenanceEventPayload(contribution: contribution))
    }
    static func appendFile(_ client: any ProvenanceEngineClient, repositoryID: String, worktreeID: String, index: Int, prefix: String, pathPrefix: String, contributionID: String?, source: ProvenanceSource, confidence: ProvenanceConfidence, timestampBase: Double) async throws {
        let changeSetID = String(format: "changeset-\(prefix)-%02d", index)
        let changeSet = ProvenanceChangeSetRecord(id: changeSetID, contributionID: contributionID, worktreeID: worktreeID, summary: String(format: "\(pathPrefix) %02d", index), diffFingerprint: String(format: "\(prefix)-%02d", index), createdAt: date(timestampBase - 10 + Double(index)))
        let file = ProvenanceFileChangeRecord(id: String(format: "file-\(prefix)-%02d", index), changeSetID: changeSetID, repositoryID: repositoryID, worktreeID: worktreeID, path: String(format: "Sources/\(pathPrefix)%02d.swift", index), status: "modified", attributionSource: source, attributionConfidence: confidence, updatedAt: date(timestampBase + Double(index)))
        try await append(client, id: "event-context-file-\(prefix)-\(index)", timestamp: timestampBase + Double(index), payload: ProvenanceEventPayload(changeSet: changeSet, fileChanges: [file]))
    }
    static func append(_ client: any ProvenanceEngineClient, id: String, timestamp: Double, payload: ProvenanceEventPayload) async throws {
        let event = ProvenanceEvent(id: id, eventType: "test_context_seed", timestamp: date(timestamp), source: .observed, confidence: .high, payload: payload)
        _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: event))
    }
    static func date(_ value: Double) -> Date { Date(timeIntervalSince1970: value) }
}

enum SeedError: Error { case invalidArguments }
