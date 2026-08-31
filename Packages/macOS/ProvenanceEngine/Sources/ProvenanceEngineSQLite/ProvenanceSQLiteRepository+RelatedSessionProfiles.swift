import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func relatedSessionProfile(
        sessionID: String
    ) throws -> RelatedSessionProfile? {
        guard let session = try session(id: sessionID) else { return nil }
        let outcome = try sessionOutcomeRecord(
            ProvenanceSessionOutcomeRequest(sessionID: sessionID)
        ).outcome
        let workModel = try sessionWorkModelSnapshot(
            ProvenanceSessionWorkModelRequest(sessionID: sessionID)
        ).model
        let externalIdentities = try externalIdentities(sessionID: sessionID)
        let providerThreads = try codingAgentThreadIDs(sessionID: sessionID)
            .compactMap { try codingAgentThread(id: $0) }
            .map(ProvenanceFactualSessionProjectionProviderThreadIdentity.init(thread:))
        let worktrees = try relatedSessionWorktrees(
            session: session,
            providerThreads: providerThreads,
            outcome: outcome
        )
        let repositories = try relatedSessionRepositories(
            worktrees: worktrees,
            outcome: outcome
        )
        return relatedSessionProfile(
            session: session,
            outcome: outcome,
            workModel: workModel,
            externalIdentities: externalIdentities,
            providerThreads: providerThreads,
            worktrees: worktrees,
            repositories: repositories
        )
    }

    func requireRelatedSessionProfile(
        _ profile: RelatedSessionProfile?,
        sessionID: String
    ) throws -> RelatedSessionProfile {
        guard let profile else {
            throw ProvenanceSQLiteError.sqlite(message: "missing related-session target: \(sessionID)")
        }
        return profile
    }

    func relatedSessionProfile(
        session: ProvenanceSessionRecord,
        outcome: ProvenanceSessionOutcome?,
        workModel: ProvenanceSessionWorkModel?,
        externalIdentities: [ProvenanceExternalIdentityRecord],
        providerThreads: [ProvenanceFactualSessionProjectionProviderThreadIdentity],
        worktrees: [ProvenanceWorktreeRecord],
        repositories: [ProvenanceRepositoryRecord]
    ) -> RelatedSessionProfile {
        var repositoryKeys = Set<String>()
        var worktreeKeys = Set<String>()
        var branchKeys = Set<String>()
        var providerThreadKeys = Set<String>()
        var externalIdentityKeys = Set<String>()
        var artifactKeys = Set<String>()
        var repositoryEvidence: [String: [ProvenanceRelatedSessionEvidenceReference]] = [:]
        var worktreeEvidence: [String: [ProvenanceRelatedSessionEvidenceReference]] = [:]
        var branchEvidence: [String: [ProvenanceRelatedSessionEvidenceReference]] = [:]
        var providerThreadEvidence: [String: [ProvenanceRelatedSessionEvidenceReference]] = [:]
        var externalIdentityEvidence: [String: [ProvenanceRelatedSessionEvidenceReference]] = [:]
        var artifactEvidence: [String: [ProvenanceRelatedSessionEvidenceReference]] = [:]
        var observedAt: [String: Date] = [:]
        var boundaries: [ProvenanceRelatedSessionWorktreeBoundary] = []
        let outcomeReference = outcome.map(relatedSessionEvidence)
        let workModelReference = workModel.map(relatedSessionEvidence)

        for repository in repositories {
            let evidence = [relatedSessionEvidence(repository)]
            for key in relatedSessionRepositoryKeys(repository) {
                repositoryKeys.insert(key)
                appendRelatedSessionEvidence(evidence, for: key, to: &repositoryEvidence)
                observedAt[key] = maxRelatedSessionDate(observedAt[key], repository.updatedAt)
            }
        }

        for worktree in worktrees {
            let repository = repositories.first { $0.id == worktree.repositoryID }
            let repositoryRecordEvidence = repository.map(relatedSessionEvidence)
            let worktreeRecordEvidence = relatedSessionEvidence(worktree)
            let evidence = [worktreeRecordEvidence] + [repositoryRecordEvidence].compactMap { $0 }
            for key in relatedSessionWorktreeKeys(worktree) {
                worktreeKeys.insert(key)
                appendRelatedSessionEvidence(evidence, for: key, to: &worktreeEvidence)
                observedAt[key] = maxRelatedSessionDate(observedAt[key], worktree.updatedAt)
            }
            for repositoryKey in relatedSessionRepositoryKeys(worktree: worktree, repository: repository) {
                repositoryKeys.insert(repositoryKey)
                appendRelatedSessionEvidence(evidence, for: repositoryKey, to: &repositoryEvidence)
                observedAt[repositoryKey] = maxRelatedSessionDate(observedAt[repositoryKey], worktree.updatedAt)
                if let branch = normalizedRelatedSessionValue(worktree.branch) {
                    let branchKey = relatedSessionBranchKey(repositoryKey: repositoryKey, branch: branch)
                    branchKeys.insert(branchKey)
                    appendRelatedSessionEvidence(evidence, for: branchKey, to: &branchEvidence)
                    observedAt[branchKey] = maxRelatedSessionDate(observedAt[branchKey], worktree.updatedAt)
                }
            }
            boundaries.append(relatedSessionBoundary(
                session: session,
                repository: repository,
                worktree: worktree,
                evidence: evidence
            ))
        }

        for thread in providerThreads {
            let key = relatedSessionProviderThreadKey(thread)
            let evidence = [relatedSessionEvidence(thread)] + [outcomeReference].compactMap { $0 }
            providerThreadKeys.insert(key)
            appendRelatedSessionEvidence(evidence, for: key, to: &providerThreadEvidence)
            observedAt[key] = maxRelatedSessionDate(observedAt[key], thread.updatedAt)
        }

        for identity in externalIdentities {
            let key = relatedSessionExternalIdentityKey(identity)
            externalIdentityKeys.insert(key)
            appendRelatedSessionEvidence([relatedSessionEvidence(identity)], for: key, to: &externalIdentityEvidence)
            observedAt[key] = maxRelatedSessionDate(observedAt[key], identity.updatedAt)
        }

        if let outcome {
            for boundary in outcome.repositoryBoundaries {
                let evidence = relatedSessionEvidence(boundary.evidence) + [relatedSessionEvidence(outcome)]
                let boundaryRepositoryKeys = relatedSessionRepositoryKeys(boundary: boundary)
                let boundaryWorktreeKeys = relatedSessionWorktreeKeys(boundary: boundary)
                for key in boundaryRepositoryKeys {
                    repositoryKeys.insert(key)
                    appendRelatedSessionEvidence(evidence, for: key, to: &repositoryEvidence)
                    observedAt[key] = maxRelatedSessionDate(observedAt[key], outcome.projection.generatedAt)
                }
                for key in boundaryWorktreeKeys {
                    worktreeKeys.insert(key)
                    appendRelatedSessionEvidence(evidence, for: key, to: &worktreeEvidence)
                    observedAt[key] = maxRelatedSessionDate(observedAt[key], outcome.projection.generatedAt)
                }
                if let branch = normalizedRelatedSessionValue(boundary.branch) {
                    for repositoryKey in boundaryRepositoryKeys {
                        let branchKey = relatedSessionBranchKey(repositoryKey: repositoryKey, branch: branch)
                        branchKeys.insert(branchKey)
                        appendRelatedSessionEvidence(evidence, for: branchKey, to: &branchEvidence)
                        observedAt[branchKey] = maxRelatedSessionDate(observedAt[branchKey], outcome.projection.generatedAt)
                    }
                }
                boundaries.append(relatedSessionBoundary(
                    session: session,
                    boundary: boundary,
                    outcome: outcome
                ))
            }

            for artifact in outcome.changedArtifacts {
                guard let path = normalizedRelatedSessionValue(artifact.artifact.path) else { continue }
                let key = relatedSessionArtifactKey(path)
                let evidence = relatedSessionEvidence(artifact.artifact.evidence) + [relatedSessionEvidence(outcome)]
                artifactKeys.insert(key)
                appendRelatedSessionEvidence(evidence, for: key, to: &artifactEvidence)
                observedAt[key] = maxRelatedSessionDate(observedAt[key], outcome.projection.generatedAt)
            }
        }

        let semanticFields = relatedSessionSemanticFields(workModel)
        let sourceEvidence = uniqueRelatedSessionEvidence(
            [outcomeReference, workModelReference].compactMap { $0 }
        )
        return RelatedSessionProfile(
            session: session,
            outcome: outcome,
            workModel: workModel,
            externalIdentities: externalIdentities,
            providerThreadIdentities: providerThreads,
            repositoryBoundaries: outcome?.repositoryBoundaries ?? [],
            worktreeBoundaries: uniqueRelatedSessionBoundaries(boundaries),
            semanticFields: semanticFields,
            repositoryKeys: repositoryKeys,
            worktreeKeys: worktreeKeys,
            branchKeys: branchKeys,
            providerThreadKeys: providerThreadKeys,
            externalIdentityKeys: externalIdentityKeys,
            artifactKeys: artifactKeys,
            repositoryEvidence: repositoryEvidence,
            worktreeEvidence: worktreeEvidence,
            branchEvidence: branchEvidence,
            providerThreadEvidence: providerThreadEvidence,
            externalIdentityEvidence: externalIdentityEvidence,
            artifactEvidence: artifactEvidence,
            observedAt: observedAt,
            sourceEvidence: sourceEvidence,
            freshnessDate: relatedSessionFreshnessDate(session: session, outcome: outcome, workModel: workModel)
        )
    }

    func relatedSessionWorktrees(
        session: ProvenanceSessionRecord,
        providerThreads: [ProvenanceFactualSessionProjectionProviderThreadIdentity],
        outcome: ProvenanceSessionOutcome?
    ) throws -> [ProvenanceWorktreeRecord] {
        var ids = Set<String>()
        if let worktreeID = session.worktreeID {
            ids.insert(worktreeID)
        }
        for thread in providerThreads {
            if let worktreeID = thread.worktreeID {
                ids.insert(worktreeID)
            }
        }
        for boundary in outcome?.repositoryBoundaries ?? [] {
            if let worktreeID = boundary.worktreeID {
                ids.insert(worktreeID)
            }
        }
        return try ids.sorted().compactMap { try worktree(id: $0) }
    }

    func relatedSessionRepositories(
        worktrees: [ProvenanceWorktreeRecord],
        outcome: ProvenanceSessionOutcome?
    ) throws -> [ProvenanceRepositoryRecord] {
        var ids = Set(worktrees.map(\.repositoryID))
        for boundary in outcome?.repositoryBoundaries ?? [] {
            if let repositoryID = boundary.repositoryID {
                ids.insert(repositoryID)
            }
        }
        return try ids.sorted().compactMap { try repository(id: $0) }
    }

    func relatedSessionBoundary(
        session: ProvenanceSessionRecord,
        repository: ProvenanceRepositoryRecord?,
        worktree: ProvenanceWorktreeRecord,
        evidence: [ProvenanceRelatedSessionEvidenceReference]
    ) -> ProvenanceRelatedSessionWorktreeBoundary {
        ProvenanceRelatedSessionWorktreeBoundary(
            id: stableIDFactory.id(
                prefix: "related-session-boundary",
                value: [
                    session.id,
                    repository?.id ?? "",
                    repository?.path ?? "",
                    worktree.id,
                    worktree.path,
                    worktree.branch ?? "",
                    worktree.currentHEAD ?? "",
                ].joined(separator: "\n")
            ),
            repositoryID: repository?.id ?? worktree.repositoryID,
            repositoryPath: repository?.path,
            worktreeID: worktree.id,
            worktreePath: worktree.path,
            branch: worktree.branch,
            head: worktree.currentHEAD,
            cwd: session.cwd,
            evidence: uniqueRelatedSessionEvidence(evidence)
        )
    }

    func relatedSessionBoundary(
        session: ProvenanceSessionRecord,
        boundary: ProvenanceSessionOutcomeRepositoryBoundary,
        outcome: ProvenanceSessionOutcome
    ) -> ProvenanceRelatedSessionWorktreeBoundary {
        let evidence = relatedSessionEvidence(boundary.evidence) + [relatedSessionEvidence(outcome)]
        return ProvenanceRelatedSessionWorktreeBoundary(
            id: stableIDFactory.id(
                prefix: "related-session-boundary",
                value: [
                    session.id,
                    boundary.repositoryID ?? "",
                    boundary.repositoryPath ?? "",
                    boundary.worktreeID ?? "",
                    boundary.worktreePath ?? "",
                    boundary.branch ?? "",
                    boundary.head ?? "",
                    boundary.cwd ?? "",
                ].joined(separator: "\n")
            ),
            repositoryID: boundary.repositoryID,
            repositoryPath: boundary.repositoryPath,
            worktreeID: boundary.worktreeID,
            worktreePath: boundary.worktreePath,
            branch: boundary.branch,
            head: boundary.head,
            cwd: boundary.cwd,
            evidence: uniqueRelatedSessionEvidence(evidence)
        )
    }

    func relatedSessionRepositoryKeys(_ repository: ProvenanceRepositoryRecord) -> [String] {
        [
            "repository_id:\(repository.id)",
            "repository_path:\(repository.path)",
            repository.remoteSlug.map { "repository_remote:\($0)" },
        ].compactMap { $0 }
    }

    func relatedSessionRepositoryKeys(
        worktree: ProvenanceWorktreeRecord,
        repository: ProvenanceRepositoryRecord?
    ) -> [String] {
        if let repository {
            return relatedSessionRepositoryKeys(repository)
        }
        return ["repository_id:\(worktree.repositoryID)"]
    }

    func relatedSessionRepositoryKeys(
        boundary: ProvenanceSessionOutcomeRepositoryBoundary
    ) -> [String] {
        [
            boundary.repositoryID.map { "repository_id:\($0)" },
            boundary.repositoryPath.map { "repository_path:\($0)" },
        ].compactMap { $0 }
    }

    func relatedSessionWorktreeKeys(_ worktree: ProvenanceWorktreeRecord) -> [String] {
        [
            "worktree_id:\(worktree.id)",
            "worktree_path:\(worktree.path)",
        ]
    }

    func relatedSessionWorktreeKeys(
        boundary: ProvenanceSessionOutcomeRepositoryBoundary
    ) -> [String] {
        [
            boundary.worktreeID.map { "worktree_id:\($0)" },
            boundary.worktreePath.map { "worktree_path:\($0)" },
        ].compactMap { $0 }
    }

    func relatedSessionBranchKey(repositoryKey: String, branch: String) -> String {
        "\(repositoryKey)|branch:\(branch)"
    }

    func relatedSessionProviderThreadKey(
        _ thread: ProvenanceFactualSessionProjectionProviderThreadIdentity
    ) -> String {
        "provider_thread:\(thread.provider):\(thread.providerThreadID)"
    }

    func relatedSessionExternalIdentityKey(
        _ identity: ProvenanceExternalIdentityRecord
    ) -> String {
        "external_identity:\(identity.system):\(identity.kind):\(identity.externalID)"
    }

    func relatedSessionArtifactKey(_ path: String) -> String {
        "artifact_path:\(path)"
    }

    func relatedSessionSemanticFields(
        _ workModel: ProvenanceSessionWorkModel?
    ) -> [ProvenanceSessionWorkModelSemanticField] {
        guard let workModel else { return [] }
        return [
            workModel.thread?.intent,
            workModel.currentTurn?.intent,
            workModel.currentTurn?.currentActivity,
            workModel.milestones,
            workModel.blockers,
            workModel.approachChanges,
            workModel.sessionPhase,
        ].compactMap { field in
            field.map(boundedRelatedSessionSemanticField)
        }
    }
}
