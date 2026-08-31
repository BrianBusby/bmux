import Foundation
import ProvenanceEngineContracts

/// Observe-only service that records Git worktree state into the provenance store.
actor WorkProvenanceObservationService {
    private let client: any ProvenanceEngineContracts.ProvenanceEngineClient
    private let gitInspector: any WorkProvenanceGitInspecting
    private let pullRequestOwnerResolver: any WorkProvenancePullRequestOwnerResolving
    private let ticketLinkResolver: any WorkProvenanceTicketLinkResolving
    private let stableIDFactory: WorkProvenanceStableIDFactory
    private let dateProvider: @Sendable () -> Date
    private var latestFingerprintByWorkspaceID: [UUID: String] = [:]
    private var latestDisplayFingerprintByWorkspaceID: [UUID: String] = [:]
    private var resolvedPullRequestOwnersByURL: [String: WorkProvenancePullRequestOwner] = [:]

    /// Last persistence or Git-observation error, retained for diagnostics.
    private(set) var lastErrorDescription: String?

    /// Creates an observe-only provenance service.
    init(
        client: any ProvenanceEngineContracts.ProvenanceEngineClient,
        gitInspector: any WorkProvenanceGitInspecting,
        pullRequestOwnerResolver: any WorkProvenancePullRequestOwnerResolving = WorkProvenanceGitHubCLIPullRequestOwnerResolver(),
        ticketLinkResolver: any WorkProvenanceTicketLinkResolving = WorkProvenanceLinearTicketLinkResolver(),
        stableIDFactory: WorkProvenanceStableIDFactory = WorkProvenanceStableIDFactory(),
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.gitInspector = gitInspector
        self.pullRequestOwnerResolver = pullRequestOwnerResolver
        self.ticketLinkResolver = ticketLinkResolver
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
        let pullRequest = await pullRequestWithResolvedOwner(workspace.pullRequest)
        // Keep ticket association tied to explicit PR evidence. Branch-only
        // workspaces must not inherit ambient ticket keys from the current repo.
        let explicitTicketIDs = Self.ticketIDs(evidenceStrings: [
            pullRequest?.title,
            pullRequest?.branch
        ].compactMap { $0 })
        let linkFacts = try await workspaceDisplayLinkFacts(
            stableWorkspaceID: workspace.stableWorkspaceID,
            explicitTicketIDs: explicitTicketIDs
        )
        let ticketIDs = linkFacts.ticketIDs
        let ticketLinks = linkFacts.ticketLinks
        let projectLinks = linkFacts.projectLinks
        let currentWorkSummary = Self.normalizedNonEmpty(workspace.currentWorkSummary)
        let lastSubmittedPrompt = Self.normalizedNonEmpty(workspace.lastSubmittedPrompt)
        let lastSubmittedPromptSessionID = lastSubmittedPrompt == nil
            ? nil
            : Self.normalizedNonEmpty(workspace.lastSubmittedPromptSessionID)
        let lastSubmittedPromptSubmittedAt = lastSubmittedPrompt == nil ? nil : workspace.lastSubmittedPromptSubmittedAt
        let fingerprint = stableIDFactory.workspaceDisplayFingerprint(
            stableWorkspaceID: workspace.stableWorkspaceID,
            title: workspace.title,
            titleSource: workspace.titleSource,
            currentDirectory: workspace.currentDirectory,
            branch: workspace.branch,
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
            explicitlyClearedFields: workspace.explicitlyClearedFields
        )
        guard latestDisplayFingerprintByWorkspaceID[workspace.workspaceID] != fingerprint else {
            return
        }
        latestDisplayFingerprintByWorkspaceID[workspace.workspaceID] = fingerprint

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
            projectLinks: projectLinks,
            currentWorkSummary: currentWorkSummary,
            lastSubmittedPrompt: lastSubmittedPrompt,
            lastSubmittedPromptSubmittedAt: lastSubmittedPromptSubmittedAt,
            lastSubmittedPromptSessionID: lastSubmittedPromptSessionID,
            clearedFields: workspace.explicitlyClearedFields,
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

    private func workspaceDisplayLinkFacts(
        stableWorkspaceID: UUID,
        explicitTicketIDs: [String]
    ) async throws -> (
        ticketIDs: [String],
        ticketLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord],
        projectLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord]
    ) {
        guard explicitTicketIDs.isEmpty else {
            let resolvedLinks = await ticketLinkResolver.workspaceLinks(for: explicitTicketIDs)
            let existingDisplay = try? await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
                workspaceID: stableWorkspaceID.uuidString
            ))
            return (
                ticketIDs: explicitTicketIDs,
                ticketLinks: Self.mergedTicketLinks(
                    ticketIDs: explicitTicketIDs,
                    incomingLinks: resolvedLinks.ticketLinks,
                    existingLinks: existingDisplay?.display?.ticketLinks ?? []
                ),
                projectLinks: Self.mergedProjectLinks(
                    incomingLinks: resolvedLinks.projectLinks,
                    existingLinks: existingDisplay?.display?.projectLinks ?? []
                )
            )
        }

        let response = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: stableWorkspaceID.uuidString
        ))
        guard let display = response.display else {
            return (ticketIDs: [], ticketLinks: [], projectLinks: [])
        }
        let ticketFacts = Self.normalizedTicketFacts(
            ticketIDs: display.ticketIDs,
            ticketLinks: display.ticketLinks
        )
        return (
            ticketIDs: ticketFacts.ids,
            ticketLinks: ticketFacts.links,
            projectLinks: Self.normalizedProjectLinks(display.projectLinks)
        )
    }

    private func pullRequestWithResolvedOwner(
        _ pullRequest: WorkProvenanceWorkspaceSnapshot.PullRequest?
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
        if shouldFetchMetadata {
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

    private static func normalizedTicketFacts(
        ticketIDs: [String],
        ticketLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord]
    ) -> (
        ids: [String],
        links: [ProvenanceWorkspaceDisplayTicketLinkRecord]
    ) {
        var seenLinkIDs = Set<String>()
        let links = ticketLinks.compactMap { link -> ProvenanceWorkspaceDisplayTicketLinkRecord? in
            guard let id = normalizedTicketID(link.id),
                  seenLinkIDs.insert(id).inserted else {
                return nil
            }
            return ProvenanceWorkspaceDisplayTicketLinkRecord(
                id: id,
                system: normalizedNonEmpty(link.system),
                title: normalizedNonEmpty(link.title),
                url: normalizedNonEmpty(link.url),
                ownerName: normalizedNonEmpty(link.ownerName),
                ownerURL: normalizedNonEmpty(link.ownerURL)
            )
        }
        var seenTicketIDs = Set<String>()
        let ids = ticketIDs.compactMap { ticketID -> String? in
            guard let id = normalizedTicketID(ticketID),
                  seenTicketIDs.insert(id).inserted else {
                return nil
            }
            return id
        }
        return (
            ids: ids.isEmpty ? links.map(\.id) : ids,
            links: links
        )
    }

    private static func normalizedProjectLinks(
        _ projectLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord]
    ) -> [ProvenanceWorkspaceDisplayProjectLinkRecord] {
        var seen = Set<String>()
        return projectLinks.compactMap { link -> ProvenanceWorkspaceDisplayProjectLinkRecord? in
            guard let id = normalizedNonEmpty(link.id),
                  seen.insert(id).inserted else {
                return nil
            }
            return ProvenanceWorkspaceDisplayProjectLinkRecord(
                id: id,
                system: normalizedNonEmpty(link.system),
                title: normalizedNonEmpty(link.title),
                url: normalizedNonEmpty(link.url)
            )
        }
    }

    private static func mergedProjectLinks(
        incomingLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord],
        existingLinks: [ProvenanceWorkspaceDisplayProjectLinkRecord]
    ) -> [ProvenanceWorkspaceDisplayProjectLinkRecord] {
        let incomingLinks = normalizedProjectLinks(incomingLinks)
        let existingLinks = normalizedProjectLinks(existingLinks)
        guard !incomingLinks.isEmpty else { return existingLinks }
        let existingByID = projectLinksByID(existingLinks)
        return incomingLinks.map { incoming in
            let existing = existingByID[incoming.id]
            return ProvenanceWorkspaceDisplayProjectLinkRecord(
                id: incoming.id,
                system: normalizedNonEmpty(incoming.system) ?? normalizedNonEmpty(existing?.system),
                title: normalizedNonEmpty(incoming.title) ?? normalizedNonEmpty(existing?.title),
                url: normalizedNonEmpty(incoming.url) ?? normalizedNonEmpty(existing?.url)
            )
        }
    }

    private static func projectLinksByID(
        _ links: [ProvenanceWorkspaceDisplayProjectLinkRecord]
    ) -> [String: ProvenanceWorkspaceDisplayProjectLinkRecord] {
        links.reduce(into: [:]) { result, link in
            guard let id = normalizedNonEmpty(link.id) else { return }
            result[id] = link
        }
    }

    private static func mergedTicketLinks(
        ticketIDs: [String],
        incomingLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord],
        existingLinks: [ProvenanceWorkspaceDisplayTicketLinkRecord]
    ) -> [ProvenanceWorkspaceDisplayTicketLinkRecord] {
        let normalizedTicketIDs = normalizedTicketFacts(ticketIDs: ticketIDs, ticketLinks: []).ids
        let incomingByID = ticketLinksByID(incomingLinks)
        let existingByID = ticketLinksByID(existingLinks)
        return normalizedTicketIDs.compactMap { id in
            let incoming = incomingByID[id]
            let existing = existingByID[id]
            guard incoming != nil || existing != nil else { return nil }
            return ProvenanceWorkspaceDisplayTicketLinkRecord(
                id: id,
                system: normalizedNonEmpty(incoming?.system) ?? normalizedNonEmpty(existing?.system),
                title: normalizedNonEmpty(incoming?.title) ?? normalizedNonEmpty(existing?.title),
                url: normalizedNonEmpty(incoming?.url) ?? normalizedNonEmpty(existing?.url),
                ownerName: normalizedNonEmpty(incoming?.ownerName) ?? normalizedNonEmpty(existing?.ownerName),
                ownerURL: normalizedNonEmpty(incoming?.ownerURL) ?? normalizedNonEmpty(existing?.ownerURL)
            )
        }
    }

    private static func ticketLinksByID(
        _ links: [ProvenanceWorkspaceDisplayTicketLinkRecord]
    ) -> [String: ProvenanceWorkspaceDisplayTicketLinkRecord] {
        links.reduce(into: [:]) { result, link in
            guard let id = normalizedTicketID(link.id) else { return }
            result[id] = link
        }
    }

    private static func ticketIDs(evidenceStrings: [String]) -> [String] {
        let pattern = #"[A-Z][A-Z0-9]+-[0-9]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        var seen = Set<String>()
        var ticketIDs: [String] = []
        for evidenceString in evidenceStrings {
            let range = NSRange(evidenceString.startIndex..<evidenceString.endIndex, in: evidenceString)
            for match in regex.matches(in: evidenceString, range: range) {
                guard let matchRange = Range(match.range, in: evidenceString) else { continue }
                let ticketID = String(evidenceString[matchRange]).uppercased()
                if seen.insert(ticketID).inserted {
                    ticketIDs.append(ticketID)
                }
            }
        }
        return ticketIDs
    }

    private static func normalizedTicketID(_ value: String?) -> String? {
        normalizedNonEmpty(value)?.uppercased()
    }

    private static func summary(fileCount: Int, isDirty: Bool) -> String {
        guard isDirty else { return "Observed clean worktree" }
        if fileCount == 1 { return "Observed 1 dirty file" }
        return "Observed \(fileCount) dirty files"
    }
}
