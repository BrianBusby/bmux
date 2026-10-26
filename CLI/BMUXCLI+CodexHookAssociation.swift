import Foundation
import ProvenanceEngineContracts

extension BMUXCLI {
    private static let codexHookAssociationRetryDeadlineSeconds: TimeInterval = 120
    private static let codexHookAssociationRetryBaseDelaySeconds: TimeInterval = 0.75

    func recordCodexHookWorkspaceSessionAssociation(
        workspaceId: String,
        surfaceId: String?,
        sessionId: String,
        turnId: String?,
        cwd: String?,
        promptObserved: Bool,
        socketPath: String?,
        env: [String: String]
    ) async {
        let normalizedSessionId = sessionId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSessionId.isEmpty else { return }
        guard let associationWorkspaceId = normalizedHookValue(env["BMUX_STABLE_WORKSPACE_ID"])
            ?? normalizedHookValue(env["CMUX_STABLE_WORKSPACE_ID"])
            ?? provenanceStableWorkspaceIDForRuntimeWorkspace(
                workspaceId,
                explicitSocketPath: socketPath,
                processEnv: env,
                cliBundleIdentifier: CLISocketPathResolver.currentAppBundleIdentifier()
            ) else {
#if DEBUG
            agentHookDebugLog(
                "codexHookAssociation.skipped session=\(agentHookDebugShort(normalizedSessionId)) workspace=\(agentHookDebugShort(workspaceId)) reason=stable_workspace_unresolved",
                socketPath: socketPath,
                env: env
            )
#endif
            return
        }

        let observedAt = Date()
        let stage = promptObserved
            ? "workspace_session_association_persisted"
            : "agent_detected_awaiting_first_prompt"
        let reasonCode = promptObserved
            ? "hook_prompt_observed"
            : "hook_session_start_observed"

        do {
            let (provenanceClient, _) = try provenanceEngineClient(databasePath: nil)
            let importer = CLIProvenanceCodexTranscriptImporter(client: provenanceClient)
            let gitContext = await importer.gitContext(for: cwd, observedAt: observedAt)
            let trimmedSurfaceId = CLIProvenanceCodexTranscriptImporter.trimmedNonEmpty(surfaceId)
            let trimmedCwd = CLIProvenanceCodexTranscriptImporter.trimmedNonEmpty(cwd)
            let association = ProvenanceWorkspaceCodingAgentSessionAssociationRecord(
                id: importer.stableIDFactory.workspaceCodingAgentSessionAssociationID(
                    workspaceID: associationWorkspaceId,
                    agentKind: "codex",
                    sessionID: normalizedSessionId
                ),
                workspaceID: associationWorkspaceId,
                sessionID: normalizedSessionId,
                agentKind: "codex",
                rawSessionID: normalizedSessionId,
                canonicalSessionID: normalizedSessionId,
                surfaceID: trimmedSurfaceId,
                repositoryID: gitContext?.repositoryID,
                worktreeID: gitContext?.worktreeID,
                currentDirectory: trimmedCwd,
                sourcePath: "hook",
                stage: stage,
                reasonCode: reasonCode,
                retryable: true,
                firstObservedAt: observedAt,
                promptObservedAt: promptObserved ? observedAt : nil,
                lastObservedAt: observedAt,
                lastTransitionAt: observedAt
            )
            let session = ProvenanceSessionRecord(
                id: normalizedSessionId,
                agentKind: "codex",
                workspaceID: associationWorkspaceId,
                surfaceID: trimmedSurfaceId,
                worktreeID: gitContext?.worktreeID,
                cwd: trimmedCwd,
                status: "active",
                startedAt: observedAt,
                updatedAt: observedAt
            )
            let identity = ProvenanceExternalIdentityRecord(
                id: importer.stableIDFactory.id(
                    prefix: "identity",
                    value: "\(normalizedSessionId)\ncodex\nhook_session\n\(normalizedSessionId)"
                ),
                sessionID: normalizedSessionId,
                system: "codex",
                kind: "hook_session",
                externalID: normalizedSessionId,
                source: .observed,
                confidence: .high,
                createdAt: observedAt,
                updatedAt: observedAt
            )
            let eventDiscriminator = [
                "codex-hook-workspace-session-association",
                associationWorkspaceId.lowercased(),
                normalizedSessionId,
                normalizedHookValue(turnId) ?? "session",
                stage,
            ].joined(separator: "\n")
            let event = ProvenanceEvent(
                id: importer.stableIDFactory.id(prefix: "event", value: eventDiscriminator),
                eventType: promptObserved ? .codingAgentPromptSubmitted : .codingAgentThreadObserved,
                timestamp: observedAt,
                repositoryID: gitContext?.repositoryID,
                worktreeID: gitContext?.worktreeID,
                sessionID: normalizedSessionId,
                source: .observed,
                evidenceOrigin: ProvenanceEvidenceOrigin(rawValue: "codex-hook"),
                evidenceScope: CLIProvenanceCodexTranscriptImporter.localEvidenceScope,
                confidence: .high,
                payload: ProvenanceEventPayload(
                    repository: gitContext?.repository,
                    worktree: gitContext?.worktree,
                    session: session,
                    externalIdentities: [identity],
                    workspaceCodingAgentSessionAssociation: association
                )
            )
            try await appendCodexHookWorkspaceSessionAssociation(
                event,
                client: provenanceClient,
                socketPath: socketPath,
                env: env
            )
#if DEBUG
            agentHookDebugLog(
                "codexHookAssociation.persisted session=\(agentHookDebugShort(normalizedSessionId)) workspace=\(agentHookDebugShort(associationWorkspaceId)) surface=\(agentHookDebugShort(trimmedSurfaceId)) stage=\(stage) reason=\(reasonCode)",
                socketPath: socketPath,
                env: env
            )
#endif
        } catch {
#if DEBUG
            agentHookDebugLog(
                "codexHookAssociation.error session=\(agentHookDebugShort(normalizedSessionId)) workspace=\(agentHookDebugShort(associationWorkspaceId)) error=\(agentHookDebugShort(String(describing: error)))",
                socketPath: socketPath,
                env: env
            )
#endif
        }
    }

    func recordCodexHookSessionStartAssociation(
        workspaceId: String,
        surfaceId: String?,
        sessionId: String,
        turnId: String?,
        cwd: String?,
        socketPath: String?,
        env: [String: String]
    ) async {
        await recordCodexHookWorkspaceSessionAssociation(
            workspaceId: workspaceId,
            surfaceId: surfaceId,
            sessionId: sessionId,
            turnId: turnId,
            cwd: cwd,
            promptObserved: false,
            socketPath: socketPath,
            env: env
        )
    }

    func recordCodexHookPromptSubmitAssociation(
        workspaceId: String,
        surfaceId: String?,
        sessionId: String,
        turnId: String?,
        cwd: String?,
        socketPath: String?,
        env: [String: String]
    ) async {
        await recordCodexHookWorkspaceSessionAssociation(
            workspaceId: workspaceId,
            surfaceId: surfaceId,
            sessionId: sessionId,
            turnId: turnId,
            cwd: cwd,
            promptObserved: true,
            socketPath: socketPath,
            env: env
        )
    }

    private func appendCodexHookWorkspaceSessionAssociation(
        _ event: ProvenanceEvent,
        client: any ProvenanceEngineContracts.ProvenanceEngineClient,
        socketPath: String?,
        env: [String: String]
    ) async throws {
        var attempts = 0
        let deadline = Date().addingTimeInterval(Self.codexHookAssociationRetryDeadlineSeconds)
        while true {
            do {
                _ = try await client.appendEvent(ProvenanceEngineContracts.ProvenanceAppendEventRequest(event: event))
                return
            } catch {
                if CLIProvenanceCodexTranscriptImporter.isDuplicateAppendError(error) {
                    return
                }
                attempts += 1
                let remaining = deadline.timeIntervalSinceNow
                guard remaining > 0, isRetryableCodexHookAssociationSQLiteError(error) else {
                    throw error
                }
                let boundedError = boundedCodexHookAssociationErrorDescription(error)
#if DEBUG
                agentHookDebugLog(
                    "codexHookAssociation.retry session=\(agentHookDebugShort(event.sessionID)) attempt=\(attempts) remaining=\(Int(remaining.rounded(.down))) error=\(boundedError)",
                    socketPath: socketPath,
                    env: env
                )
#endif
                // Bounded retry covers transient SQLite writer contention in the detached hook worker.
                let delay = min(
                    remaining,
                    Self.codexHookAssociationRetryBaseDelaySeconds * Double(min(attempts, 8))
                )
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    private func boundedCodexHookAssociationErrorDescription(_ error: Error) -> String {
        let description = String(describing: error)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return String(description.prefix(160))
    }

    private func isRetryableCodexHookAssociationSQLiteError(_ error: Error) -> Bool {
        let description = String(describing: error).lowercased()
        return description.contains("database is locked")
            || description.contains("database is busy")
            || description.contains("busy")
            || description.contains("locked")
    }

}
