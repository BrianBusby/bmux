import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct ProjectionRebuildValidationTests {
    @Test
    func repairRebuildsDeletedProjectionsToIdenticalQueryResults() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = ProjectionRebuildFixture()

        try await Self.seed(fixture, into: repository)

        let beforeWorktrees = try await repository.worktrees(ProvenanceWorktreeListRequest(repositoryID: nil))
        let beforeCurrentContext = try await repository.currentContext(
            ProvenanceCurrentContextRequest(repositoryPath: fixture.repository.path)
        )
        let beforeFileExplanation = try await repository.fileExplanation(
            ProvenanceFileExplanationRequest(worktreeID: fixture.worktree.id, path: fixture.fileChange.path)
        )
        let beforeSessionTree = try await repository.sessionTree(
            ProvenanceSessionTreeRequest(rootSessionID: fixture.session.id)
        )

        try Self.deleteProjectionRows(databaseURL: url)
        #expect(try await repository.currentContext(
            ProvenanceCurrentContextRequest(repositoryPath: fixture.repository.path)
        ).found == false)

        let repair = try await repository.repairProjectionDrift(
            validationLimit: 20,
            mismatchLimit: 20,
            rebuildBatchSize: 2
        )

        #expect(repair.repaired)
        #expect(repair.replayedEventCount == 6)
        #expect(repair.postRepairValidation?.mismatches.isEmpty == true)
        #expect(try await repository.worktrees(ProvenanceWorktreeListRequest(repositoryID: nil)) == beforeWorktrees)
        #expect(try await repository.currentContext(
            ProvenanceCurrentContextRequest(repositoryPath: fixture.repository.path)
        ) == beforeCurrentContext)
        #expect(try await repository.fileExplanation(
            ProvenanceFileExplanationRequest(worktreeID: fixture.worktree.id, path: fixture.fileChange.path)
        ) == beforeFileExplanation)
        #expect(try await repository.sessionTree(
            ProvenanceSessionTreeRequest(rootSessionID: fixture.session.id)
        ) == beforeSessionTree)
    }

    private static func seed(
        _ fixture: ProjectionRebuildFixture,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        try await append(
            eventID: "event-rebuild-worktree",
            eventType: .worktreeObserved,
            timestamp: fixture.timestamp,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            payload: ProvenanceEventPayload(repository: fixture.repository, worktree: fixture.worktree),
            into: repository
        )
        try await append(
            eventID: "event-rebuild-session",
            eventType: .sessionObserved,
            timestamp: fixture.session.updatedAt,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            payload: ProvenanceEventPayload(session: fixture.session),
            into: repository
        )
        try await append(
            eventID: "event-rebuild-task",
            eventType: .workItemConfirmed,
            timestamp: fixture.contribution.updatedAt,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            contributionID: fixture.contribution.id,
            payload: ProvenanceEventPayload(workItem: fixture.workItem, contribution: fixture.contribution),
            into: repository
        )
        try await append(
            eventID: "event-rebuild-checkpoint",
            eventType: .progressCheckpoint,
            timestamp: fixture.checkpoint.createdAt,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            contributionID: fixture.contribution.id,
            payload: ProvenanceEventPayload(checkpoint: fixture.checkpoint),
            into: repository
        )
        try await append(
            eventID: "event-rebuild-file",
            eventType: "file_modified",
            timestamp: fixture.fileChange.updatedAt,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            contributionID: fixture.contribution.id,
            payload: ProvenanceEventPayload(changeSet: fixture.changeSet, fileChanges: [fixture.fileChange]),
            into: repository
        )
        try await append(
            eventID: "event-rebuild-validation",
            eventType: "validation_completed",
            timestamp: fixture.validationRun.endedAt ?? fixture.timestamp,
            repositoryID: fixture.repository.id,
            worktreeID: fixture.worktree.id,
            sessionID: fixture.session.id,
            contributionID: fixture.contribution.id,
            payload: ProvenanceEventPayload(validationRun: fixture.validationRun),
            into: repository
        )
    }

    private static func append(
        eventID: String,
        eventType: ProvenanceEventType,
        timestamp: Date,
        repositoryID: String,
        worktreeID: String,
        sessionID: String? = nil,
        contributionID: String? = nil,
        payload: ProvenanceEventPayload,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        try await repository.appendEvent(
            ProvenanceEvent(
                id: eventID,
                eventType: eventType,
                timestamp: timestamp,
                repositoryID: repositoryID,
                worktreeID: worktreeID,
                sessionID: sessionID,
                contributionID: contributionID,
                source: .observed,
                evidenceOrigin: "projection-rebuild-validation",
                evidenceScope: ProvenanceEvidenceScope(level: .personal, id: "local-test"),
                confidence: .high,
                payload: payload
            )
        )
    }

    private static func deleteProjectionRows(databaseURL: URL) throws {
        let database = try ProvenanceSQLiteDatabase(url: databaseURL)
        try database.execute(
            """
            DELETE FROM provenance_repositories;
            DELETE FROM provenance_worktrees;
            DELETE FROM provenance_sessions;
            DELETE FROM provenance_session_relationships;
            DELETE FROM provenance_session_external_identities;
            DELETE FROM provenance_work_items;
            DELETE FROM provenance_work_contributions;
            DELETE FROM provenance_checkpoints;
            DELETE FROM provenance_change_sets;
            DELETE FROM provenance_file_changes;
            DELETE FROM provenance_validation_runs;
            """
        )
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-projection-rebuild-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

private struct ProjectionRebuildFixture {
    let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
    let repository: ProvenanceRepositoryRecord
    let worktree: ProvenanceWorktreeRecord
    let session: ProvenanceSessionRecord
    let workItem: ProvenanceWorkItemRecord
    let contribution: ProvenanceContributionRecord
    let checkpoint: ProvenanceCheckpointRecord
    let changeSet: ProvenanceChangeSetRecord
    let fileChange: ProvenanceFileChangeRecord
    let validationRun: ProvenanceValidationRunRecord

    init() {
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = ProvenanceRepositoryRecord(
            id: "repository-rebuild",
            path: "/repos/projection-rebuild",
            remoteSlug: "owner/projection-rebuild",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let worktree = ProvenanceWorktreeRecord(
            id: "worktree-rebuild",
            repositoryID: repository.id,
            path: repository.path,
            branch: "main",
            currentHEAD: "head-rebuild",
            isDirty: true,
            status: "active",
            lastReconciledAt: timestamp,
            updatedAt: timestamp
        )
        let session = ProvenanceSessionRecord(
            id: "session-rebuild",
            agentKind: "generic-agent",
            worktreeID: worktree.id,
            cwd: repository.path,
            status: "active",
            startedAt: timestamp.addingTimeInterval(1),
            updatedAt: timestamp.addingTimeInterval(1)
        )
        let workItem = ProvenanceWorkItemRecord(
            id: "work-item-rebuild",
            title: "Rebuild projection validation",
            status: "active",
            createdAt: timestamp.addingTimeInterval(2),
            updatedAt: timestamp.addingTimeInterval(2)
        )
        let contribution = ProvenanceContributionRecord(
            id: "contribution-rebuild",
            sessionID: session.id,
            worktreeID: worktree.id,
            workItemID: workItem.id,
            declaredIntent: "Prove disposable projections",
            expectedScope: ["Sources/Rebuild.swift"],
            status: "active",
            startedAt: timestamp.addingTimeInterval(2),
            assignmentConfidence: .high,
            updatedAt: timestamp.addingTimeInterval(2)
        )
        let checkpoint = ProvenanceCheckpointRecord(
            id: "checkpoint-rebuild",
            contributionID: contribution.id,
            sequence: 1,
            gitHEAD: "head-rebuild",
            diffFingerprint: "diff-rebuild",
            summary: "Projection rebuild checkpoint",
            status: "completed",
            validationState: "passed",
            semanticConfidence: .medium,
            freshness: "fresh",
            createdAt: timestamp.addingTimeInterval(3)
        )
        let changeSet = ProvenanceChangeSetRecord(
            id: "change-set-rebuild",
            checkpointID: checkpoint.id,
            contributionID: contribution.id,
            worktreeID: worktree.id,
            summary: "Projection rebuild file change",
            diffFingerprint: "diff-rebuild",
            createdAt: timestamp.addingTimeInterval(4)
        )
        let fileChange = ProvenanceFileChangeRecord(
            id: "file-change-rebuild",
            changeSetID: changeSet.id,
            repositoryID: repository.id,
            worktreeID: worktree.id,
            path: "Sources/Rebuild.swift",
            status: "modified",
            attributionSource: .observed,
            attributionConfidence: .high,
            updatedAt: timestamp.addingTimeInterval(4)
        )
        let validationRun = ProvenanceValidationRunRecord(
            id: "validation-rebuild",
            checkpointID: checkpoint.id,
            contributionID: contribution.id,
            command: "swift test --filter ProjectionRebuildValidationTests",
            status: "passed",
            summary: "Projection rebuild validation passed",
            startedAt: timestamp.addingTimeInterval(5),
            endedAt: timestamp.addingTimeInterval(6)
        )

        self.repository = repository
        self.worktree = worktree
        self.session = session
        self.workItem = workItem
        self.contribution = contribution
        self.checkpoint = checkpoint
        self.changeSet = changeSet
        self.fileChange = fileChange
        self.validationRun = validationRun
    }
}
