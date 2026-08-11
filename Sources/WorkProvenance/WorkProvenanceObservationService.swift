import Foundation
import ProvenanceEngineContracts

/// Observe-only service that records Git worktree state into the provenance store.
actor WorkProvenanceObservationService {
    private let client: any ProvenanceEngineContracts.ProvenanceEngineClient
    private let gitInspector: any WorkProvenanceGitInspecting
    private let stableIDFactory: WorkProvenanceStableIDFactory
    private let dateProvider: @Sendable () -> Date
    private var latestFingerprintByWorkspaceID: [UUID: String] = [:]
    private var latestDisplayFingerprintByWorkspaceID: [UUID: String] = [:]

    /// Last persistence or Git-observation error, retained for diagnostics.
    private(set) var lastErrorDescription: String?

    /// Creates an observe-only provenance service.
    init(
        client: any ProvenanceEngineContracts.ProvenanceEngineClient,
        gitInspector: any WorkProvenanceGitInspecting,
        stableIDFactory: WorkProvenanceStableIDFactory = WorkProvenanceStableIDFactory(),
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.gitInspector = gitInspector
        self.stableIDFactory = stableIDFactory
        self.dateProvider = dateProvider
    }

    /// Observes each workspace snapshot and appends events when Git state changed.
    func observeWorkspaceSnapshots(_ snapshots: [WorkProvenanceWorkspaceSnapshot]) async {
        for snapshot in snapshots {
            await observeWorkspaceSnapshot(snapshot)
        }
    }

    /// Runs a retention pass for stale observed history.
    func pruneExpiredObservedHistory(now: Date = Date()) async {
        lastErrorDescription = nil
    }

    /// Observes one workspace snapshot and appends an event when Git state changed.
    func observeWorkspaceSnapshot(_ snapshot: WorkProvenanceWorkspaceSnapshot) async {
        do {
            try await appendObservationIfChanged(for: snapshot)
            lastErrorDescription = nil
        } catch {
            let description = String(describing: error)
            lastErrorDescription = description
            NSLog("bmux provenance worktree observation failed: %@", description)
        }
    }

    private func appendObservationIfChanged(for workspace: WorkProvenanceWorkspaceSnapshot) async throws {
        let directory = workspace.currentDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        StartupBreadcrumbLog.append("workProvenance.observe.begin", fields: ["workspace": workspace.workspaceID.uuidString, "directory": directory])
        guard !directory.isEmpty else { return }
        guard let gitSnapshot = await gitInspector.snapshot(for: directory) else {
            try await appendWorkspaceDisplayObservationIfChanged(
                for: workspace,
                gitSnapshot: nil
            )
            let description = "no Git snapshot for workspace directory: \(directory)"
            lastErrorDescription = description
            NSLog("bmux provenance worktree observation skipped: %@", description)
            StartupBreadcrumbLog.append("workProvenance.observe.noGitSnapshot", fields: ["workspace": workspace.workspaceID.uuidString, "directory": directory])
            return
        }

        try await appendWorkspaceDisplayObservationIfChanged(
            for: workspace,
            gitSnapshot: gitSnapshot
        )

        let fingerprint = stableIDFactory.fingerprint(for: gitSnapshot)
        guard latestFingerprintByWorkspaceID[workspace.workspaceID] != fingerprint else {
            return
        }
        latestFingerprintByWorkspaceID[workspace.workspaceID] = fingerprint

        let now = dateProvider()
        let repositoryID = stableIDFactory.repositoryID(repositoryRoot: gitSnapshot.repositoryRoot)
        let worktreeID = stableIDFactory.worktreeID(repositoryRoot: gitSnapshot.repositoryRoot)
        let changeSetID = stableIDFactory.changeSetID(worktreeID: worktreeID, fingerprint: fingerprint)

        let repository = ProvenanceRepositoryRecord(
            id: repositoryID,
            path: gitSnapshot.repositoryRoot,
            commonDirectory: gitSnapshot.commonDirectory,
            remoteSlug: gitSnapshot.remoteSlug,
            createdAt: now,
            updatedAt: now
        )
        let worktree = ProvenanceWorktreeRecord(
            id: worktreeID,
            repositoryID: repositoryID,
            path: gitSnapshot.repositoryRoot,
            branch: gitSnapshot.branch,
            currentHEAD: gitSnapshot.headCommit,
            isDirty: gitSnapshot.isDirty,
            status: "active",
            lastReconciledAt: now,
            updatedAt: now
        )
        let changeSet = ProvenanceEngineContracts.ProvenanceChangeSetRecord(
            id: changeSetID,
            worktreeID: worktreeID,
            summary: Self.summary(fileCount: gitSnapshot.statusEntries.count, isDirty: gitSnapshot.isDirty),
            diffFingerprint: fingerprint,
            createdAt: now
        )
        let fileChanges = gitSnapshot.statusEntries.map { entry in
            ProvenanceEngineContracts.ProvenanceFileChangeRecord(
                id: stableIDFactory.fileChangeID(worktreeID: worktreeID, path: entry.path),
                changeSetID: changeSetID,
                repositoryID: repositoryID,
                worktreeID: worktreeID,
                path: entry.path,
                status: entry.status,
                attributionSource: ProvenanceEngineContracts.ProvenanceSource.unattributed,
                attributionConfidence: ProvenanceEngineContracts.ProvenanceConfidence.low,
                updatedAt: now
            )
        }
        let event = ProvenanceEngineContracts.ProvenanceEvent(
            eventType: .worktreeObserved,
            timestamp: now,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            source: ProvenanceEngineContracts.ProvenanceSource.observed,
            evidenceOrigin: ProvenanceEngineContracts.ProvenanceEvidenceOrigin(rawValue: "bmux-work-provenance-observation"),
            evidenceScope: ProvenanceEngineContracts.ProvenanceEvidenceScope(level: .personal, id: "bmux-local"),
            confidence: gitSnapshot.statusEntries.isEmpty
                ? ProvenanceEngineContracts.ProvenanceConfidence.high
                : ProvenanceEngineContracts.ProvenanceConfidence.medium,
            payload: ProvenanceEngineContracts.ProvenanceEventPayload(
                repository: repository,
                worktree: worktree,
                changeSet: changeSet,
                fileChanges: fileChanges
            )
        )

        let response = try await client.appendEvent(ProvenanceEngineContracts.ProvenanceAppendEventRequest(event: event))
        StartupBreadcrumbLog.append("workProvenance.observe.appended", fields: ["workspace": workspace.workspaceID.uuidString, "eventID": response.eventID, "eventType": response.eventType, "database": "canonical"])
    }

    private func appendWorkspaceDisplayObservationIfChanged(
        for workspace: WorkProvenanceWorkspaceSnapshot,
        gitSnapshot: WorkProvenanceGitSnapshot?
    ) async throws {
        let ticketIDs = Self.ticketIDs(
            branchNames: [
                workspace.branch,
                gitSnapshot?.branch,
                workspace.pullRequest?.branch
            ].compactMap { $0 }
        )
        let ticketLinks = Self.ticketLinks(ticketIDs: ticketIDs)
        let fingerprint = stableIDFactory.workspaceDisplayFingerprint(
            stableWorkspaceID: workspace.stableWorkspaceID,
            title: workspace.title,
            titleSource: workspace.titleSource,
            currentDirectory: workspace.currentDirectory,
            branch: workspace.branch,
            pullRequestNumber: workspace.pullRequest?.number,
            pullRequestURL: workspace.pullRequest?.url,
            pullRequestOwnerLogin: workspace.pullRequest?.ownerLogin,
            pullRequestOwnerURL: workspace.pullRequest?.ownerURL,
            pullRequestStatus: workspace.pullRequest?.status,
            pullRequestBranch: workspace.pullRequest?.branch,
            pullRequestIsStale: workspace.pullRequest?.isStale ?? false,
            gitSnapshot: gitSnapshot,
            ticketIDs: ticketIDs,
            ticketLinks: ticketLinks
        )
        guard latestDisplayFingerprintByWorkspaceID[workspace.workspaceID] != fingerprint else {
            return
        }
        latestDisplayFingerprintByWorkspaceID[workspace.workspaceID] = fingerprint

        let now = dateProvider()
        let repositoryID = gitSnapshot.map { stableIDFactory.repositoryID(repositoryRoot: $0.repositoryRoot) }
        let worktreeID = gitSnapshot.map { stableIDFactory.worktreeID(repositoryRoot: $0.repositoryRoot) }
        let pullRequest = workspace.pullRequest
        let display = ProvenanceEngineContracts.ProvenanceWorkspaceDisplayRecord(
            id: stableIDFactory.workspaceDisplayID(stableWorkspaceID: workspace.stableWorkspaceID),
            workspaceID: workspace.stableWorkspaceID.uuidString,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            currentDirectory: workspace.currentDirectory,
            title: workspace.title,
            titleSource: workspace.titleSource,
            branch: workspace.branch ?? gitSnapshot?.branch,
            pullRequestNumber: pullRequest?.number,
            pullRequestURL: pullRequest?.url,
            pullRequestOwnerLogin: pullRequest?.ownerLogin,
            pullRequestOwnerURL: pullRequest?.ownerURL,
            pullRequestStatus: pullRequest?.status,
            pullRequestBranch: pullRequest?.branch,
            pullRequestIsStale: pullRequest?.isStale ?? false,
            isDirty: gitSnapshot?.isDirty,
            ticketIDs: ticketIDs,
            ticketLinks: ticketLinks,
            observedAt: now,
            updatedAt: now
        )
        let event = ProvenanceEngineContracts.ProvenanceEvent(
            id: stableIDFactory.workspaceDisplayEventID(
                stableWorkspaceID: workspace.stableWorkspaceID,
                fingerprint: fingerprint
            ),
            eventType: .workspaceDisplayObserved,
            timestamp: now,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            source: ProvenanceEngineContracts.ProvenanceSource.observed,
            evidenceOrigin: ProvenanceEngineContracts.ProvenanceEvidenceOrigin(rawValue: "bmux-work-provenance-observation"),
            evidenceScope: ProvenanceEngineContracts.ProvenanceEvidenceScope(level: .personal, id: "bmux-local"),
            confidence: ProvenanceEngineContracts.ProvenanceConfidence.high,
            payload: ProvenanceEngineContracts.ProvenanceEventPayload(
                workspaceDisplay: display
            )
        )

        let response = try await client.appendEvent(ProvenanceEngineContracts.ProvenanceAppendEventRequest(event: event))
        StartupBreadcrumbLog.append("workProvenance.observe.workspaceDisplayAppended", fields: ["workspace": workspace.workspaceID.uuidString, "eventID": response.eventID, "eventType": response.eventType, "database": "canonical"])
    }

    private static func summary(fileCount: Int, isDirty: Bool) -> String {
        guard isDirty else { return "Observed clean worktree" }
        if fileCount == 1 { return "Observed 1 dirty file" }
        return "Observed \(fileCount) dirty files"
    }

    private static func ticketIDs(branchNames: [String]) -> [String] {
        let pattern = #"[A-Z][A-Z0-9]+-[0-9]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var seen = Set<String>()
        var ticketIDs: [String] = []
        for branchName in branchNames {
            let normalized = branchName.uppercased()
            let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
            for match in regex.matches(in: normalized, range: range) {
                guard let matchRange = Range(match.range, in: normalized) else { continue }
                let ticketID = String(normalized[matchRange])
                if seen.insert(ticketID).inserted {
                    ticketIDs.append(ticketID)
                }
            }
        }
        return ticketIDs
    }

    private static func ticketLinks(
        ticketIDs: [String]
    ) -> [ProvenanceEngineContracts.ProvenanceWorkspaceDisplayTicketLinkRecord] {
        ticketIDs.map { ticketID in
            ProvenanceEngineContracts.ProvenanceWorkspaceDisplayTicketLinkRecord(id: ticketID)
        }
    }
}
