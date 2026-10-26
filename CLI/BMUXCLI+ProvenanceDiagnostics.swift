import Foundation
import BmuxAgentChat
import ProvenanceEngineContracts
import ProvenanceEngineSDK

extension BMUXCLI {
    func runProvenanceDiagnostics(
        commandArgs: [String],
        jsonOutput: Bool,
        explicitSocketPath: String? = nil,
        processEnv: [String: String] = ProcessInfo.processInfo.environment,
        cliBundleIdentifier: String? = CLISocketPathResolver.currentAppBundleIdentifier()
    ) async throws {
        let commandName = "provenance diagnostics"
        let (databasePath, remainingAfterDatabase) = parseOption(commandArgs, name: "--database")
        var remaining = remainingAfterDatabase
        try rejectProvenanceUnknownFlags(Array(remaining.prefix(1)), commandName: commandName)
        guard let diagnosticName = remaining.first?.lowercased() else {
            throw CLIError(message: String(
                localized: "cli.provenance.diagnostics.usage",
                defaultValue: "Usage: bmux provenance diagnostics <workspace-display|execution-telemetry-live|codex-transcript> [...]"
            ))
        }
        remaining.removeFirst()

        if diagnosticName == "codex-transcript" {
            try await runProvenanceCodexTranscriptDiagnostics(
                commandArgs: remaining, jsonOutput: jsonOutput, databasePath: databasePath
            )
            return
        }

        if diagnosticName == "workspace-display" {
            let (workspaceIDText, remainingAfterWorkspace) = parseOption(
                remaining,
                name: "--workspace"
            )
            remaining = remainingAfterWorkspace
            try rejectProvenanceUnknownFlags(remaining, commandName: "provenance diagnostics workspace-display")
            guard let workspaceID = workspaceIDText?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !workspaceID.isEmpty else {
                throw CLIError(message: String(
                    localized: "cli.provenance.diagnostics.workspaceDisplay.usage",
                    defaultValue: "Usage: bmux provenance diagnostics workspace-display --workspace <workspace-id> [--database <path>] [--json]"
                ))
            }
            guard remaining.isEmpty else {
                throw CLIError(message: provenanceUnexpectedArgumentMessage(commandName: commandName, argument: remaining[0]))
            }

            let response: ProvenanceEngineContracts.ProvenanceWorkspaceDisplayResponse
            let databaseURL: URL
            var resolvedWorkspaceID: String?
            if let overrideURL = provenanceDatabaseOverrideURL(databasePath: databasePath),
               !FileManager.default.fileExists(atPath: overrideURL.path) {
                databaseURL = overrideURL
                response = ProvenanceEngineContracts.ProvenanceWorkspaceDisplayResponse(
                    found: false,
                    reason: "no_database",
                    workspaceID: workspaceID,
                    display: nil
                )
            } else {
                let resolved = try provenanceEngineClient(databasePath: databasePath)
                databaseURL = resolved.databaseURL
                let directResponse = try await resolved.client.workspaceDisplay(ProvenanceEngineContracts.ProvenanceWorkspaceDisplayRequest(
                    workspaceID: workspaceID
                ))
                if directResponse.found {
                    response = directResponse
                } else if let stableWorkspaceID = provenanceStableWorkspaceIDForRuntimeWorkspace(
                    workspaceID,
                    explicitSocketPath: explicitSocketPath,
                    processEnv: processEnv,
                    cliBundleIdentifier: cliBundleIdentifier
                ),
                    stableWorkspaceID != workspaceID {
                    let stableResponse = try await resolved.client.workspaceDisplay(
                        ProvenanceEngineContracts.ProvenanceWorkspaceDisplayRequest(
                            workspaceID: stableWorkspaceID
                        )
                    )
                    response = stableResponse
                    resolvedWorkspaceID = stableWorkspaceID
                } else {
                    response = directResponse
                }
            }

            let payload = provenanceWorkspaceDisplayDiagnosticPayload(
                workspaceID: workspaceID,
                resolvedWorkspaceID: resolvedWorkspaceID,
                databaseURL: databaseURL,
                response: response
            )
            printProvenanceWorkspaceDisplayDiagnostic(payload, jsonOutput: jsonOutput)
            return
        }

        guard diagnosticName == "execution-telemetry-live" else {
            throw CLIError(message: String(
                localized: "cli.provenance.diagnostics.usage",
                defaultValue: "Usage: bmux provenance diagnostics <workspace-display|execution-telemetry-live|codex-transcript> [...]"
            ))
        }
        let (agentChatURLText, remainingAfterAgentChatURL) = parseOption(
            remaining,
            name: "--agent-chat-url"
        )
        let (repositoryPath, remainingAfterRepository) = parseOption(
            remainingAfterAgentChatURL,
            name: "--repository"
        )
        remaining = remainingAfterRepository
        try rejectProvenanceUnknownFlags(remaining, commandName: "provenance diagnostics execution-telemetry-live")
        guard let sessionID = remaining.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !sessionID.isEmpty else {
            throw CLIError(message: String(
                localized: "cli.provenance.diagnostics.executionTelemetry.usage",
                defaultValue: "Usage: bmux provenance diagnostics execution-telemetry-live <session-id> [--agent-chat-url <url>] [--repository <path>] [--database <path>] [--json]"
            ))
        }
        remaining.removeFirst()
        guard remaining.isEmpty else {
            throw CLIError(message: provenanceUnexpectedArgumentMessage(commandName: commandName, argument: remaining[0]))
        }

        let agentChatURL = try provenanceExecutionTelemetryAgentChatURL(agentChatURLText)
        let livePayload: ExecutionTelemetryLiveProjectionReadPayload
        do {
            livePayload = try await ExecutionTelemetryLiveProjectionClient(baseURL: agentChatURL).read(sessionID: sessionID)
        } catch {
            throw CLIError(message: String(
                localized: "cli.provenance.diagnostics.executionTelemetry.error.liveReadFailed",
                defaultValue: "failed to read live execution telemetry projection"
            ))
        }

        let target = try CLIProvenanceGitResolver().resolve(
            path: repositoryPath ?? ".",
            commandLabel: commandName
        )
        let currentContext: ProvenanceEngineContracts.ProvenanceCurrentContextResponse
        if let databaseURL = provenanceDatabaseOverrideURL(databasePath: databasePath),
           !FileManager.default.fileExists(atPath: databaseURL.path) {
            currentContext = ProvenanceEngineContracts.ProvenanceCurrentContextResponse(
                found: false,
                reason: "no_database",
                repositoryPath: target.repositoryRoot,
                worktree: nil,
                repository: nil,
                activeSessions: [],
                dirtyFiles: [],
                unattributedChanges: [],
                recentCheckpoints: [],
                validationRuns: [],
                conflicts: []
            )
        } else {
            let (client, _) = try provenanceEngineClient(databasePath: databasePath)
            currentContext = try await client.currentContext(ProvenanceEngineContracts.ProvenanceCurrentContextRequest(
                repositoryPath: target.repositoryRoot
            ))
        }

        let payload = provenanceExecutionTelemetryObservationDiagnosticPayload(
            sessionID: sessionID,
            livePayload: livePayload,
            currentContext: currentContext
        )
        printProvenanceExecutionTelemetryObservationDiagnostic(payload, jsonOutput: jsonOutput)
    }

}
