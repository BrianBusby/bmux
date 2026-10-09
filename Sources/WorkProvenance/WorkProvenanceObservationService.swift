import Foundation
import ProvenanceEngineContracts

/// Observe-only service that records Git worktree state into the provenance store.
actor WorkProvenanceObservationService {
    private let client: any ProvenanceEngineContracts.ProvenanceEngineClient
    private let gitInspector: any WorkProvenanceGitInspecting
    private let pullRequestOwnerResolver: any WorkProvenancePullRequestOwnerResolving
    private let resourceLinker: WorkProvenanceWorkspaceDisplayResourceLinker
    private let stableIDFactory: WorkProvenanceStableIDFactory
    private let dateProvider: @Sendable () -> Date
    private let retryDelay: @Sendable (Duration) async throws -> Void
    private var observationsByWorkspaceID: [UUID: (id: UUID, snapshot: WorkProvenanceWorkspaceSnapshot)] = [:]
    private var latestFingerprintByWorkspaceID: [UUID: String] = [:]
    private var latestDisplayFingerprintByWorkspaceID: [UUID: String] = [:]
    private var resolvedPullRequestOwnersByURL: [String: WorkProvenancePullRequestOwner] = [:]

    /// Last persistence or Git-observation error, retained for diagnostics.
    private(set) var lastErrorDescription: String?

    /// Creates an observe-only provenance service.
    init(
        client: any ProvenanceEngineContracts.ProvenanceEngineClient,
        gitInspector: any WorkProvenanceGitInspecting,
        pullRequestOwnerResolver: any WorkProvenancePullRequestOwnerResolving = WorkProvenanceNoopPullRequestOwnerResolver(),
        ticketLinkResolver: any WorkProvenanceTicketLinkResolving = WorkProvenanceLinearTicketLinkResolver(),
        resourceDiscovery: WorkProvenanceWorkspaceResourceDiscovery = WorkProvenanceWorkspaceResourceDiscovery(),
        stableIDFactory: WorkProvenanceStableIDFactory = WorkProvenanceStableIDFactory(),
        dateProvider: @escaping @Sendable () -> Date = { Date() },
        retryDelay: @escaping @Sendable (Duration) async throws -> Void = {
            try await ContinuousClock().sleep(for: $0)
        }
    ) {
        self.client = client
        self.gitInspector = gitInspector
        self.pullRequestOwnerResolver = pullRequestOwnerResolver
        self.resourceLinker = WorkProvenanceWorkspaceDisplayResourceLinker(
            ticketLinkResolver: ticketLinkResolver,
            resourceDiscovery: resourceDiscovery
        )
        self.stableIDFactory = stableIDFactory
        self.dateProvider = dateProvider
        self.retryDelay = retryDelay
    }

    /// Observes each workspace snapshot and appends events when Git state changed.
    func observeWorkspaceSnapshots(_ snapshots: [WorkProvenanceWorkspaceSnapshot]) async {
        // One workspace's optional enrichment must not hold back another workspace's known facts.
        await withTaskGroup(of: Void.self) { group in
            for snapshot in snapshots {
                group.addTask { await self.observeWorkspaceSnapshot(snapshot) }
            }
        }
    }

    /// Runs a retention pass for stale observed history.
    func pruneExpiredObservedHistory(now: Date = Date()) async {
        lastErrorDescription = nil
    }

    /// Observes one workspace snapshot and appends an event when Git state changed.
    func observeWorkspaceSnapshot(_ snapshot: WorkProvenanceWorkspaceSnapshot) async {
        guard observationsByWorkspaceID[snapshot.workspaceID]?.snapshot != snapshot else { return }
        let observationID = UUID()
        observationsByWorkspaceID[snapshot.workspaceID] = (observationID, snapshot)
        defer {
            if observationsByWorkspaceID[snapshot.workspaceID]?.id == observationID {
                observationsByWorkspaceID[snapshot.workspaceID] = nil
            }
        }
        for attempt in 0..<3 {
            guard !Task.isCancelled,
                  observationsByWorkspaceID[snapshot.workspaceID]?.id == observationID else { return }
            do {
                try await appendObservationIfChanged(for: snapshot, observationID: observationID)
                lastErrorDescription = nil
                return
            } catch {
                guard !Task.isCancelled else { return }
                let description = String(describing: error)
                lastErrorDescription = description
                NSLog("bmux provenance worktree observation failed: %@", description)
                guard attempt < 2 else { return }
                do {
                    // Genuine bounded backoff gives the competing writer time to release its lock.
                    try await retryDelay(.milliseconds(250 * (attempt + 1)))
                } catch {
                    return
                }
            }
        }
    }

    private func observationIsCurrent(_ workspaceID: UUID, _ observationID: UUID) -> Bool {
        !Task.isCancelled && observationsByWorkspaceID[workspaceID]?.id == observationID
    }

    private func appendObservationIfChanged(
        for workspace: WorkProvenanceWorkspaceSnapshot, observationID: UUID
    ) async throws {
        let directory = workspace.currentDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        StartupBreadcrumbLog.append("workProvenance.observe.begin", fields: ["workspace": workspace.workspaceID.uuidString, "directory": directory])
        guard !directory.isEmpty else { return }
        guard let gitSnapshot = await gitInspector.snapshot(for: directory) else {
            for includesEnrichment in [false, true] {
                try await appendWorkspaceDisplayObservationIfChanged(
                    for: workspace, gitSnapshot: nil, observationID: observationID,
                    includesEnrichment: includesEnrichment
                )
            }
            let description = "no Git snapshot for workspace directory: \(directory)"
            lastErrorDescription = description
            NSLog("bmux provenance worktree observation skipped: %@", description)
            StartupBreadcrumbLog.append("workProvenance.observe.noGitSnapshot", fields: ["workspace": workspace.workspaceID.uuidString, "directory": directory])
            return
        }

        for includesEnrichment in [false, true] {
            try await appendWorkspaceDisplayObservationIfChanged(
                for: workspace, gitSnapshot: gitSnapshot, observationID: observationID,
                includesEnrichment: includesEnrichment
            )
        }

        guard observationIsCurrent(workspace.workspaceID, observationID) else { return }
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

        do {
            let response = try await client.appendEvent(ProvenanceEngineContracts.ProvenanceAppendEventRequest(event: event))
            StartupBreadcrumbLog.append("workProvenance.observe.appended", fields: ["workspace": workspace.workspaceID.uuidString, "eventID": response.eventID, "eventType": response.eventType, "database": "canonical"])
        } catch {
            // Preserve a newer in-flight observation while making this failed snapshot retryable.
            if latestFingerprintByWorkspaceID[workspace.workspaceID] == fingerprint {
                latestFingerprintByWorkspaceID[workspace.workspaceID] = nil
            }
            throw error
        }
    }

    private func appendWorkspaceDisplayObservationIfChanged(
        for workspace: WorkProvenanceWorkspaceSnapshot,
        gitSnapshot: WorkProvenanceGitSnapshot?, observationID: UUID,
        includesEnrichment: Bool
    ) async throws {
        guard observationIsCurrent(workspace.workspaceID, observationID) else { return }
        var pullRequest = await pullRequestWithResolvedOwner(workspace.pullRequest, allowsLookup: includesEnrichment)
        guard observationIsCurrent(workspace.workspaceID, observationID) else { return }
        let existingDisplayResponse = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: workspace.stableWorkspaceID.uuidString
        ))
        guard observationIsCurrent(workspace.workspaceID, observationID) else { return }
        if !includesEnrichment, let current = pullRequest,
           let stored = existingDisplayResponse.display, stored.pullRequestURL == current.url {
            pullRequest = current.replacingResolvedMetadata(
                login: current.ownerLogin ?? stored.pullRequestOwnerLogin,
                url: current.ownerURL ?? stored.pullRequestOwnerURL,
                title: current.title, branch: current.branch ?? stored.pullRequestBranch
            )
        }
        let linkFacts = await resourceLinker.linkFacts(
            pullRequest: pullRequest,
            lastSubmittedPrompt: workspace.lastSubmittedPrompt,
            existingDisplay: existingDisplayResponse.display,
            includesEnrichment: includesEnrichment
        )
        guard observationIsCurrent(workspace.workspaceID, observationID) else { return }
        let ticketIDs = linkFacts.ticketIDs
        let ticketLinks = linkFacts.ticketLinks
        let projectLinks = linkFacts.projectLinks
        let currentWorkSummary = Self.normalizedNonEmpty(workspace.currentWorkSummary)
        let lastSubmittedPrompt = Self.normalizedNonEmpty(workspace.lastSubmittedPrompt)
        let lastSubmittedPromptSessionID = lastSubmittedPrompt == nil
            ? nil
            : Self.normalizedCodingAgentSessionID(workspace.lastSubmittedPromptSessionID)
        let lastSubmittedPromptSubmittedAt = lastSubmittedPrompt == nil ? nil : workspace.lastSubmittedPromptSubmittedAt
        let branch = gitSnapshot != nil ? gitSnapshot?.branch : workspace.branch
        var clearedFields = Set(workspace.explicitlyClearedFields)
        if gitSnapshot != nil, branch == nil { clearedFields.insert("branch") }
        let explicitlyClearedFields = clearedFields.sorted()
        let fingerprint = stableIDFactory.workspaceDisplayFingerprint(
            stableWorkspaceID: workspace.stableWorkspaceID,
            title: workspace.title,
            titleSource: workspace.titleSource,
            currentDirectory: workspace.currentDirectory,
            branch: branch,
            pullRequestNumber: pullRequest?.number,
            pullRequestURL: pullRequest?.url,
            pullRequestOwnerLogin: pullRequest?.ownerLogin,
            pullRequestOwnerURL: pullRequest?.ownerURL,
            pullRequestStatus: pullRequest?.status,
            pullRequestBranch: pullRequest?.branch,
            pullRequestIsStale: pullRequest?.isStale ?? false,
            gitSnapshot: gitSnapshot,
            ticketIDs: ticketIDs,
            ticketLinks: ticketLinks,
            projectLinks: projectLinks,
            currentWorkSummary: currentWorkSummary,
            lastSubmittedPrompt: lastSubmittedPrompt,
            lastSubmittedPromptSessionID: lastSubmittedPromptSessionID,
            lastSubmittedPromptSubmittedAt: lastSubmittedPromptSubmittedAt,
            explicitlyClearedFields: explicitlyClearedFields
        )
        guard latestDisplayFingerprintByWorkspaceID[workspace.workspaceID] != fingerprint else {
            return
        }
        let eventID = stableIDFactory.workspaceDisplayEventID(
            stableWorkspaceID: workspace.stableWorkspaceID, fingerprint: fingerprint
        )
        latestDisplayFingerprintByWorkspaceID[workspace.workspaceID] = fingerprint
        // A new observer can encounter an identical baseline already committed by an earlier one.
        guard existingDisplayResponse.display?.latestEventID != eventID else { return }

        let now = dateProvider()
        let repositoryID = gitSnapshot.map { stableIDFactory.repositoryID(repositoryRoot: $0.repositoryRoot) }
        let worktreeID = gitSnapshot.map { stableIDFactory.worktreeID(repositoryRoot: $0.repositoryRoot) }
        let display = ProvenanceEngineContracts.ProvenanceWorkspaceDisplayRecord(
            id: stableIDFactory.workspaceDisplayID(stableWorkspaceID: workspace.stableWorkspaceID),
            workspaceID: workspace.stableWorkspaceID.uuidString,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            currentDirectory: workspace.currentDirectory,
            title: workspace.title,
            titleSource: workspace.titleSource,
            branch: branch,
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
            projectLinks: projectLinks,
            currentWorkSummary: currentWorkSummary,
            lastSubmittedPrompt: lastSubmittedPrompt,
            lastSubmittedPromptSubmittedAt: lastSubmittedPromptSubmittedAt,
            lastSubmittedPromptSessionID: lastSubmittedPromptSessionID,
            clearedFields: explicitlyClearedFields,
            observedAt: now,
            updatedAt: now
        )
        let association = lastSubmittedPromptSessionID.map { sessionID in
            ProvenanceEngineContracts.ProvenanceWorkspaceCodingAgentSessionAssociationRecord(
                id: stableIDFactory.workspaceCodingAgentSessionAssociationID(
                    stableWorkspaceID: workspace.stableWorkspaceID,
                    agentKind: "codex",
                    sessionID: sessionID
                ),
                workspaceID: workspace.stableWorkspaceID.uuidString,
                sessionID: sessionID,
                agentKind: "codex",
                rawSessionID: sessionID,
                canonicalSessionID: sessionID,
                repositoryID: repositoryID,
                worktreeID: worktreeID,
                currentDirectory: workspace.currentDirectory,
                sourcePath: "display",
                stage: "workspace_session_association_persisted",
                reasonCode: "workspace_display_prompt_session_observed",
                retryable: true,
                firstObservedAt: lastSubmittedPromptSubmittedAt ?? now,
                promptObservedAt: lastSubmittedPromptSubmittedAt,
                lastObservedAt: now,
                lastTransitionAt: now
            )
        }
        let event = ProvenanceEngineContracts.ProvenanceEvent(
            id: eventID,
            eventType: .workspaceDisplayObserved,
            timestamp: now,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            source: ProvenanceEngineContracts.ProvenanceSource.observed,
            evidenceOrigin: ProvenanceEngineContracts.ProvenanceEvidenceOrigin(rawValue: "bmux-work-provenance-observation"),
            evidenceScope: ProvenanceEngineContracts.ProvenanceEvidenceScope(level: .personal, id: "bmux-local"),
            confidence: ProvenanceEngineContracts.ProvenanceConfidence.high,
            payload: ProvenanceEngineContracts.ProvenanceEventPayload(
                workspaceDisplay: display,
                workspaceCodingAgentSessionAssociation: association
            )
        )

        do {
            let response = try await client.appendEvent(ProvenanceEngineContracts.ProvenanceAppendEventRequest(event: event))
            StartupBreadcrumbLog.append("workProvenance.observe.workspaceDisplayAppended", fields: ["workspace": workspace.workspaceID.uuidString, "eventID": response.eventID, "eventType": response.eventType, "database": "canonical"])
        } catch {
            // Preserve a newer in-flight observation while making this failed snapshot retryable.
            if latestDisplayFingerprintByWorkspaceID[workspace.workspaceID] == fingerprint {
                latestDisplayFingerprintByWorkspaceID[workspace.workspaceID] = nil
            }
            throw error
        }
    }

    private func pullRequestWithResolvedOwner(
        _ pullRequest: WorkProvenanceWorkspaceSnapshot.PullRequest?, allowsLookup: Bool
    ) async -> WorkProvenanceWorkspaceSnapshot.PullRequest? {
        guard let pullRequest else { return nil }
        let existingOwnerLogin = Self.normalizedNonEmpty(pullRequest.ownerLogin)
        let existingTitle = Self.normalizedNonEmpty(pullRequest.title)
        let existingBranch = Self.normalizedNonEmpty(pullRequest.branch)
        let existingOwnerURL = existingOwnerLogin.flatMap {
            Self.normalizedOwnerURL(pullRequest.ownerURL, login: $0)
        }

        let resolvedMetadata = resolvedPullRequestOwnersByURL[pullRequest.url]
        let shouldFetchMetadata =
            (existingOwnerLogin == nil && Self.normalizedNonEmpty(resolvedMetadata?.login) == nil) ||
            (existingTitle == nil && Self.normalizedNonEmpty(resolvedMetadata?.title) == nil) ||
            (existingBranch == nil && Self.normalizedNonEmpty(resolvedMetadata?.branch) == nil)
        let fetchedMetadata: WorkProvenancePullRequestOwner?
        if shouldFetchMetadata && allowsLookup {
            fetchedMetadata = await pullRequestOwnerResolver.owner(for: pullRequest.url)
        } else {
            fetchedMetadata = nil
        }
        if let fetchedMetadata {
            resolvedPullRequestOwnersByURL[pullRequest.url] = fetchedMetadata
        }
        let metadata = resolvedMetadata ?? fetchedMetadata
        let ownerLogin = existingOwnerLogin ?? Self.normalizedNonEmpty(metadata?.login)
        let ownerURL = ownerLogin.flatMap {
            Self.normalizedOwnerURL(existingOwnerURL ?? metadata?.url, login: $0)
        }
        let title = existingTitle ?? Self.normalizedNonEmpty(metadata?.title)
        let branch = existingBranch ?? Self.normalizedNonEmpty(metadata?.branch)
        return pullRequest.replacingResolvedMetadata(
            login: ownerLogin,
            url: ownerURL,
            title: title,
            branch: branch
        )
    }

    private static func normalizedOwnerURL(_ url: String?, login: String) -> String? {
        if let url = normalizedNonEmpty(url) {
            return url
        }
        return "https://github.com/\(login)"
    }

    private static func normalizedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func normalizedCodingAgentSessionID(_ value: String?) -> String? {
        guard let sessionID = normalizedNonEmpty(value) else { return nil }
        let codexHookPrefix = "codex-"
        guard sessionID.hasPrefix(codexHookPrefix) else { return sessionID }
        let candidate = String(sessionID.dropFirst(codexHookPrefix.count))
        guard UUID(uuidString: candidate) != nil else {
            return sessionID
        }
        return candidate
    }

    private static func summary(fileCount: Int, isDirty: Bool) -> String {
        guard isDirty else { return "Observed clean worktree" }
        if fileCount == 1 { return "Observed 1 dirty file" }
        return "Observed \(fileCount) dirty files"
    }
}
