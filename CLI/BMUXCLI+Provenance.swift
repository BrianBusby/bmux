import Foundation
import BmuxAgentChat
import ProvenanceEngineContracts
import ProvenanceEngineSDK

extension BMUXCLI {
    func runProvenanceCommand(
        commandArgs: [String],
        jsonOutput: Bool,
        explicitSocketPath: String? = nil,
        processEnv: [String: String] = ProcessInfo.processInfo.environment,
        cliBundleIdentifier: String? = CLISocketPathResolver.currentAppBundleIdentifier()
    ) async throws {
        let subcommand = commandArgs.first?.lowercased()
        switch subcommand {
        case "explain":
            try await runProvenanceExplain(
                commandArgs: Array(commandArgs.dropFirst()),
                jsonOutput: jsonOutput
            )
        case "context":
            try await runProvenanceContext(
                commandArgs: Array(commandArgs.dropFirst()),
                jsonOutput: jsonOutput
            )
        case "worktrees":
            try await runProvenanceWorktrees(
                commandArgs: Array(commandArgs.dropFirst()),
                jsonOutput: jsonOutput
            )
        case "sessions":
            try await runProvenanceSessions(
                commandArgs: Array(commandArgs.dropFirst()),
                jsonOutput: jsonOutput
            )
        case "import":
            try await runProvenanceImport(
                commandArgs: Array(commandArgs.dropFirst()),
                jsonOutput: jsonOutput
            )
        case "traces":
            try runProvenanceTraces(
                commandArgs: Array(commandArgs.dropFirst()),
                jsonOutput: jsonOutput
            )
        case "diagnostics":
            try await runProvenanceDiagnostics(
                commandArgs: Array(commandArgs.dropFirst()),
                jsonOutput: jsonOutput,
                explicitSocketPath: explicitSocketPath,
                processEnv: processEnv,
                cliBundleIdentifier: cliBundleIdentifier
            )
        case "help", "--help", "-h", nil:
            print(provenanceUsage())
        default:
            throw CLIError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.error.unknownSubcommand",
                    defaultValue: "Unknown provenance subcommand: %@\n\n%@"
                ),
                subcommand ?? "",
                provenanceUsage()
            ))
        }
    }

    private func runProvenanceExplain(commandArgs: [String], jsonOutput: Bool) async throws {
        let commandName = "provenance explain"
        let (databasePath, remainingAfterDatabase) = parseOption(commandArgs, name: "--database")
        var remaining = remainingAfterDatabase
        try rejectProvenanceUnknownFlags(remaining, commandName: commandName)
        guard let path = remaining.first else {
            throw CLIError(message: String(localized: "cli.provenance.error.requiresPath", defaultValue: "Usage: bmux provenance explain <path> [--json]"))
        }
        remaining.removeFirst()
        guard remaining.isEmpty else {
            throw CLIError(message: provenanceUnexpectedArgumentMessage(commandName: commandName, argument: remaining[0]))
        }

        let target = try CLIProvenanceGitResolver().resolve(path: path, commandLabel: commandName)
        if let databaseURL = provenanceDatabaseOverrideURL(databasePath: databasePath),
           !FileManager.default.fileExists(atPath: databaseURL.path) {
            let explanation = CLIProvenanceExplanation(
                requestedPath: target.requestedPath,
                repositoryPath: target.repositoryRoot,
                relativePath: target.relativePath,
                found: false,
                reason: String(localized: "cli.provenance.reason.noDatabase", defaultValue: "no provenance database exists yet"),
                fileStatus: nil,
                attributionSource: nil,
                attributionConfidence: nil,
                updatedAt: nil,
                worktree: ["path": target.repositoryRoot],
                repository: ["path": target.repositoryRoot],
                changeSet: nil,
                checkpoint: nil,
                contribution: nil,
                session: nil,
                workItem: nil
            )
            printProvenanceExplanation(explanation, jsonOutput: jsonOutput)
            return
        }
        let (client, _) = try provenanceEngineClient(databasePath: databasePath)
        let worktrees = try await client.worktrees(ProvenanceWorktreeListRequest())
        guard let worktreeEntry = worktrees.worktrees.first(where: { $0.worktree.path == target.repositoryRoot }) else {
            let explanation = CLIProvenanceExplanation(
                requestedPath: target.requestedPath,
                repositoryPath: target.repositoryRoot,
                relativePath: target.relativePath,
                found: false,
                reason: String(localized: "cli.provenance.reason.noWorktree", defaultValue: "no provenance has been recorded for this Git worktree"),
                fileStatus: nil,
                attributionSource: nil,
                attributionConfidence: nil,
                updatedAt: nil,
                worktree: ["path": target.repositoryRoot],
                repository: ["path": target.repositoryRoot],
                changeSet: nil,
                checkpoint: nil,
                contribution: nil,
                session: nil,
                workItem: nil
            )
            printProvenanceExplanation(explanation, jsonOutput: jsonOutput)
            return
        }

        let response = try await client.fileExplanation(ProvenanceFileExplanationRequest(
            worktreeID: worktreeEntry.worktree.id,
            path: target.relativePath
        ))
        let explanation = CLIProvenanceExplanation(
            target: target,
            response: response,
            worktree: worktreeEntry.worktree,
            repository: worktreeEntry.repository,
            noFileReason: String(localized: "cli.provenance.reason.noFile", defaultValue: "no file-level provenance has been recorded for this path")
        )
        printProvenanceExplanation(explanation, jsonOutput: jsonOutput)
    }

    private func runProvenanceContext(commandArgs: [String], jsonOutput: Bool) async throws {
        let commandName = "provenance context current"
        let (databasePath, remainingAfterDatabase) = parseOption(commandArgs, name: "--database")
        var remaining = remainingAfterDatabase
        try rejectProvenanceUnknownFlags(remaining, commandName: commandName)
        guard remaining.first?.lowercased() == "current" else {
            throw CLIError(message: String(localized: "cli.provenance.context.usage", defaultValue: "Usage: bmux provenance context current [--json]"))
        }
        remaining.removeFirst()
        guard remaining.isEmpty else {
            throw CLIError(message: provenanceUnexpectedArgumentMessage(commandName: commandName, argument: remaining[0]))
        }

        let target = try CLIProvenanceGitResolver().resolve(path: ".", commandLabel: commandName)
        if let databaseURL = provenanceDatabaseOverrideURL(databasePath: databasePath),
           !FileManager.default.fileExists(atPath: databaseURL.path) {
            let context = CLIProvenanceContext(
                found: false,
                reason: String(localized: "cli.provenance.reason.noDatabase", defaultValue: "no provenance database exists yet"),
                repositoryPath: target.repositoryRoot,
                worktree: ["path": target.repositoryRoot],
                repository: ["path": target.repositoryRoot],
                activeSessions: [],
                dirtyFiles: [],
                unattributedChanges: [],
                recentCheckpoints: [],
                validationRuns: [],
                conflicts: []
            )
            printProvenanceContext(context, jsonOutput: jsonOutput)
            return
        }

        let (client, _) = try provenanceEngineClient(databasePath: databasePath)
        let response = try await client.currentContext(ProvenanceEngineContracts.ProvenanceCurrentContextRequest(
            repositoryPath: target.repositoryRoot
        ))
        let context = CLIProvenanceContext(
            response: response,
            fallbackRepositoryPath: target.repositoryRoot,
            noWorktreeReason: String(
                localized: "cli.provenance.reason.noWorktree",
                defaultValue: "no provenance has been recorded for this Git worktree"
            )
        )
        printProvenanceContext(context, jsonOutput: jsonOutput)
    }

    private func runProvenanceWorktrees(commandArgs: [String], jsonOutput: Bool) async throws {
        let commandName = "provenance worktrees list"
        let (databasePath, remainingAfterDatabase) = parseOption(commandArgs, name: "--database")
        var remaining = remainingAfterDatabase
        try rejectProvenanceUnknownFlags(remaining, commandName: commandName)
        guard remaining.first?.lowercased() == "list" else {
            throw CLIError(message: String(localized: "cli.provenance.worktrees.usage", defaultValue: "Usage: bmux provenance worktrees list [--json]"))
        }
        remaining.removeFirst()
        guard remaining.isEmpty else {
            throw CLIError(message: provenanceUnexpectedArgumentMessage(commandName: commandName, argument: remaining[0]))
        }

        if let databaseURL = provenanceDatabaseOverrideURL(databasePath: databasePath),
           !FileManager.default.fileExists(atPath: databaseURL.path) {
            let list = CLIProvenanceWorktreeList(
                worktrees: [],
                reason: String(localized: "cli.provenance.reason.noDatabase", defaultValue: "no provenance database exists yet")
            )
            printProvenanceWorktreeList(list, jsonOutput: jsonOutput)
            return
        }

        let (client, _) = try provenanceEngineClient(databasePath: databasePath)
        let response = try await client.worktrees(ProvenanceWorktreeListRequest())
        let list = CLIProvenanceWorktreeList(response: response)
        printProvenanceWorktreeList(list, jsonOutput: jsonOutput)
    }

    private func runProvenanceSessions(commandArgs: [String], jsonOutput: Bool) async throws {
        let commandName = "provenance sessions tree"
        let (databasePath, remainingAfterDatabase) = parseOption(commandArgs, name: "--database")
        var remaining = remainingAfterDatabase
        try rejectProvenanceUnknownFlags(remaining, commandName: commandName)
        guard remaining.first?.lowercased() == "tree" else {
            throw CLIError(message: String(localized: "cli.provenance.sessions.usage", defaultValue: "Usage: bmux provenance sessions tree <session-id> [--database <path>] [--json]"))
        }
        remaining.removeFirst()
        guard let sessionID = remaining.first else {
            throw CLIError(message: String(localized: "cli.provenance.sessions.usage", defaultValue: "Usage: bmux provenance sessions tree <session-id> [--database <path>] [--json]"))
        }
        remaining.removeFirst()
        guard remaining.isEmpty else {
            throw CLIError(message: provenanceUnexpectedArgumentMessage(commandName: commandName, argument: remaining[0]))
        }

        if let databaseURL = provenanceDatabaseOverrideURL(databasePath: databasePath),
           !FileManager.default.fileExists(atPath: databaseURL.path) {
            let tree = CLIProvenanceSessionTree(
                rootSessionID: sessionID,
                found: false,
                reason: String(localized: "cli.provenance.reason.noDatabase", defaultValue: "no provenance database exists yet"),
                sessions: [],
                relationships: [],
                externalIdentities: []
            )
            printProvenanceSessionTree(tree, jsonOutput: jsonOutput)
            return
        }

        let legacySessionLimit = 100
        let engineRowLimit = (legacySessionLimit * 2) - 1
        let (client, _) = try provenanceEngineClient(databasePath: databasePath)
        let response = try await client.sessionTree(ProvenanceEngineContracts.ProvenanceSessionTreeRequest(
            rootSessionID: sessionID,
            limit: engineRowLimit
        ))
        let tree = CLIProvenanceSessionTree(
            response: response,
            noSessionReason: String(localized: "cli.provenance.reason.noSession", defaultValue: "no provenance has been recorded for this session"),
            externalIdentityLimit: 200
        )
        printProvenanceSessionTree(tree, jsonOutput: jsonOutput)
    }

    private func runProvenanceImport(commandArgs: [String], jsonOutput: Bool) async throws {
        let commandName = "provenance import codex-transcripts"
        let (databasePath, remainingAfterDatabase) = parseOption(commandArgs, name: "--database")
        let (path, remainingAfterPath) = parseOption(remainingAfterDatabase, name: "--path")
        let (limitText, remainingAfterLimit) = parseOption(remainingAfterPath, name: "--limit")
        var remaining = remainingAfterLimit
        try rejectProvenanceUnknownFlags(remaining, commandName: commandName)
        guard remaining.first?.lowercased() == "codex-transcripts" else {
            throw CLIError(message: String(
                localized: "cli.provenance.import.usage",
                defaultValue: "Usage: bmux provenance import codex-transcripts [--path <path>] [--limit <count>] [--database <path>] [--json]"
            ))
        }
        remaining.removeFirst()
        guard remaining.isEmpty else {
            throw CLIError(message: provenanceUnexpectedArgumentMessage(commandName: commandName, argument: remaining[0]))
        }

        let limit = try provenanceImportLimit(limitText, commandName: commandName)
        let (client, databaseURL) = try provenanceEngineClient(databasePath: databasePath)
        let importer = CLIProvenanceCodexTranscriptImporter(client: client)
        let report = try await importer.importTranscripts(path: path, limit: limit)
        printProvenanceCodexTranscriptImport(report, databaseURL: databaseURL, jsonOutput: jsonOutput)
    }

    private func runProvenanceDiagnostics(
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
                defaultValue: "Usage: bmux provenance diagnostics <workspace-display|execution-telemetry-live> [...]"
            ))
        }
        remaining.removeFirst()

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
                defaultValue: "Usage: bmux provenance diagnostics <workspace-display|execution-telemetry-live> [...]"
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

    private func runProvenanceTraces(commandArgs: [String], jsonOutput: Bool) throws {
        let commandName = "provenance traces lifecycle-ingestion"
        let (databasePath, remainingAfterDatabase) = parseOption(
            commandArgs,
            name: "--observability-database"
        )
        let (limitText, remainingAfterLimit) = parseOption(remainingAfterDatabase, name: "--limit")
        let (pipelineRunID, remainingAfterRun) = parseOption(remainingAfterLimit, name: "--run")
        let (parentSessionID, remainingAfterParentSession) = parseOption(
            remainingAfterRun,
            name: "--parent-session"
        )
        let (childSessionID, remainingAfterChildSession) = parseOption(
            remainingAfterParentSession,
            name: "--child-session"
        )
        let (statusText, remainingAfterStatus) = parseOption(
            remainingAfterChildSession,
            name: "--status"
        )
        var remaining = remainingAfterStatus
        try rejectProvenanceUnknownFlags(remaining, commandName: commandName)
        guard remaining.first?.lowercased() == "lifecycle-ingestion" else {
            throw CLIError(message: String(localized: "cli.provenance.traces.usage", defaultValue: "Usage: bmux provenance traces lifecycle-ingestion [--observability-database <path>] [--limit <count>] [--run <pipeline-run-id>] [--parent-session <session-id>] [--child-session <session-id>] [--status <status>] [--json]"))
        }
        remaining.removeFirst()
        guard remaining.isEmpty else {
            throw CLIError(message: provenanceUnexpectedArgumentMessage(commandName: commandName, argument: remaining[0]))
        }

        let limit = try provenanceTraceLimit(limitText, commandName: commandName)
        let status = try provenanceTraceStatus(statusText, commandName: commandName)
        let databaseURL = provenanceObservabilityDatabaseURL(databasePath: databasePath)
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            let list = CLIProvenanceLifecycleTraceList(
                found: false,
                reason: String(localized: "cli.provenance.reason.noObservabilityDatabase", defaultValue: "no provenance observability database exists yet"),
                runs: [],
                stages: [],
                identityResolutions: [],
                projectionLineage: []
            )
            printProvenanceLifecycleTraceList(list, jsonOutput: jsonOutput)
            return
        }

        let reader = try CLIProvenanceObservabilitySQLiteReader(databaseURL: databaseURL)
        let list = try reader.lifecycleIngestionTraces(
            limit: limit,
            pipelineRunID: provenanceTraceFilterValue(pipelineRunID),
            parentSessionID: provenanceTraceFilterValue(parentSessionID),
            childSessionID: provenanceTraceFilterValue(childSessionID),
            status: status
        )
        printProvenanceLifecycleTraceList(list, jsonOutput: jsonOutput)
    }

    private func rejectProvenanceUnknownFlags(_ args: [String], commandName: String) throws {
        if let unknown = args.first(where: { $0.hasPrefix("--") }) {
            throw CLIError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.error.commandUnknownFlag",
                    defaultValue: "%@: unknown flag '%@'"
                ),
                commandName,
                unknown
            ))
        }
    }

    private func provenanceUnexpectedArgumentMessage(commandName: String, argument: String) -> String {
        String.localizedStringWithFormat(
            String(
                localized: "cli.provenance.error.commandUnexpectedArgument",
                defaultValue: "%@: unexpected argument '%@'"
            ),
            commandName,
            argument
        )
    }

    private func provenanceEngineClient(
        databasePath: String?
    ) throws -> (client: any ProvenanceEngineContracts.ProvenanceEngineClient, databaseURL: URL) {
        if let databaseURL = provenanceDatabaseOverrideURL(databasePath: databasePath) {
            return (
                try ProvenanceEngineClientFactory().sqliteClient(databaseURL: databaseURL),
                databaseURL
            )
        }
        let homeDirectory = WorkProvenanceStorageLocation.defaultHomeDirectory()
        let location = WorkProvenanceStorageLocation(homeDirectory: homeDirectory)
        return (
            try ProvenanceEngineClientFactory().defaultSQLiteClient(homeDirectory: homeDirectory),
            location.databaseURL
        )
    }

    private func provenanceDatabaseOverrideURL(databasePath: String?) -> URL? {
        if let databasePath = databasePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !databasePath.isEmpty {
            return URL(fileURLWithPath: NSString(string: databasePath).expandingTildeInPath)
        }
        return nil
    }

    private func provenanceObservabilityDatabaseURL(databasePath: String?) -> URL {
        if let databasePath = databasePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !databasePath.isEmpty {
            return URL(fileURLWithPath: NSString(string: databasePath).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
            .appendingPathComponent("bmux", isDirectory: true)
            .appendingPathComponent("work-provenance", isDirectory: true)
            .appendingPathComponent("ProvenanceObservability.sqlite", isDirectory: false)
    }

    private func provenanceTraceLimit(_ value: String?, commandName: String) throws -> Int {
        guard let value else { return 20 }
        guard let parsed = Int(value), parsed > 0 else {
            throw CLIError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.traces.error.invalidLimit",
                    defaultValue: "%@: --limit must be a positive integer"
                ),
                commandName
            ))
        }
        return min(parsed, 100)
    }

    private func provenanceTraceStatus(_ value: String?, commandName: String) throws -> String? {
        guard let value = provenanceTraceFilterValue(value) else { return nil }
        let normalized = value.lowercased()
        let allowedStatuses = [
            "running",
            "succeeded",
            "partially_succeeded",
            "failed",
            "cancelled",
            "degraded",
        ]
        guard allowedStatuses.contains(normalized) else {
            throw CLIError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.traces.error.invalidStatus",
                    defaultValue: "%@: --status must be one of running, succeeded, partially_succeeded, failed, cancelled, or degraded"
                ),
                commandName
            ))
        }
        return normalized
    }

    private func provenanceImportLimit(_ value: String?, commandName: String) throws -> Int? {
        guard let value = provenanceTraceFilterValue(value) else { return nil }
        guard let parsed = Int(value), parsed > 0 else {
            throw CLIError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.import.error.invalidLimit",
                    defaultValue: "%@: --limit must be a positive integer"
                ),
                commandName
            ))
        }
        return parsed
    }

    private func provenanceExecutionTelemetryAgentChatURL(_ value: String?) throws -> URL {
        let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        let text: String
        if let raw, !raw.isEmpty {
            text = raw
        } else {
            text = "http://127.0.0.1:7739"
        }
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host?.isEmpty == false else {
            throw CLIError(message: String(
                localized: "cli.provenance.diagnostics.executionTelemetry.error.invalidAgentChatURL",
                defaultValue: "provenance diagnostics execution-telemetry-live requires an absolute http or https --agent-chat-url"
            ))
        }
        return url
    }

    private func provenanceTraceFilterValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func printProvenanceExplanation(_ explanation: CLIProvenanceExplanation, jsonOutput: Bool) {
        if jsonOutput {
            print(jsonString(explanation.payload))
            return
        }
        print(renderProvenanceExplanation(explanation))
    }

    private func printProvenanceContext(_ context: CLIProvenanceContext, jsonOutput: Bool) {
        if jsonOutput {
            print(jsonString(context.payload))
            return
        }
        print(renderProvenanceContext(context))
    }

    private func printProvenanceWorktreeList(_ list: CLIProvenanceWorktreeList, jsonOutput: Bool) {
        if jsonOutput {
            print(jsonString(list.payload))
            return
        }
        print(renderProvenanceWorktreeList(list))
    }

    private func printProvenanceSessionTree(_ tree: CLIProvenanceSessionTree, jsonOutput: Bool) {
        if jsonOutput {
            print(jsonString(tree.payload))
            return
        }
        print(renderProvenanceSessionTree(tree))
    }

    private func printProvenanceLifecycleTraceList(
        _ list: CLIProvenanceLifecycleTraceList,
        jsonOutput: Bool
    ) {
        if jsonOutput {
            print(jsonString(list.payload))
            return
        }
        print(renderProvenanceLifecycleTraceList(list))
    }

    private func printProvenanceCodexTranscriptImport(
        _ report: CLIProvenanceCodexTranscriptImporter.Report,
        databaseURL: URL,
        jsonOutput: Bool
    ) {
        if jsonOutput {
            var payload = report.payload
            payload["database"] = databaseURL.path
            print(jsonString(payload))
            return
        }
        print(renderProvenanceCodexTranscriptImport(report, databaseURL: databaseURL))
    }

    private func printProvenanceExecutionTelemetryObservationDiagnostic(
        _ payload: [String: Any],
        jsonOutput: Bool
    ) {
        if jsonOutput {
            print(jsonString(payload))
            return
        }
        print(renderProvenanceExecutionTelemetryObservationDiagnostic(payload))
    }

    private func printProvenanceWorkspaceDisplayDiagnostic(
        _ payload: [String: Any],
        jsonOutput: Bool
    ) {
        if jsonOutput {
            print(jsonString(payload))
            return
        }
        print(renderProvenanceWorkspaceDisplayDiagnostic(payload))
    }

    private func renderProvenanceExplanation(_ explanation: CLIProvenanceExplanation) -> String {
        if !explanation.found {
            return [
                String.localizedStringWithFormat(
                    String(localized: "cli.provenance.output.noProvenance", defaultValue: "No provenance found for %@"),
                    explanation.relativePath
                ),
                explanation.reason.map {
                    String.localizedStringWithFormat(
                        String(localized: "cli.provenance.output.reason", defaultValue: "Reason: %@"),
                        $0
                    )
                },
                String.localizedStringWithFormat(
                    String(localized: "cli.provenance.output.repository", defaultValue: "Repository: %@"),
                    explanation.repositoryPath
                )
            ].compactMap(\.self).joined(separator: "\n")
        }

        var lines: [String] = [
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.output.header", defaultValue: "Provenance for %@"),
                explanation.relativePath
            )
        ]
        if let fileStatus = explanation.fileStatus {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.output.status", defaultValue: "Status: %@"),
                fileStatus
            ))
        }
        if let source = explanation.attributionSource,
           let confidence = explanation.attributionConfidence {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.output.attribution", defaultValue: "Attribution: %@ (%@ confidence)"),
                source,
                confidence
            ))
        }
        if let updatedAt = explanation.updatedAt {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.output.observed", defaultValue: "Observed: %@"),
                formattedProvenanceDate(updatedAt)
            ))
        }
        if let summary = explanation.changeSet?["summary"] as? String {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.output.changeSet", defaultValue: "Change set: %@"),
                summary
            ))
        }
        if let fingerprint = explanation.changeSet?["diff_fingerprint"] as? String {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.output.diffFingerprint", defaultValue: "Diff fingerprint: %@"),
                fingerprint
            ))
        }
        if let contribution = explanation.contribution {
            let id = contribution["id"] as? String
            let status = contribution["status"] as? String
            let intent = contribution["declared_intent"] as? String
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.output.contribution", defaultValue: "Contribution: %@"),
                [id, status].compactMap(\.self).joined(separator: " · ")
            ))
            if let intent, !intent.isEmpty {
                lines.append(String.localizedStringWithFormat(
                    String(localized: "cli.provenance.output.intent", defaultValue: "Intent: %@"),
                    intent
                ))
            }
        }
        if let session = explanation.session,
           let sessionID = session["id"] as? String {
            let agent = session["agent_kind"] as? String
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.output.session", defaultValue: "Session: %@"),
                [sessionID, agent].compactMap(\.self).joined(separator: " · ")
            ))
        }
        if let workItem = explanation.workItem,
           let title = workItem["title"] as? String {
            let id = workItem["id"] as? String
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.output.workItem", defaultValue: "Work item: %@"),
                [id, title].compactMap(\.self).joined(separator: " · ")
            ))
        }
        if let branch = explanation.worktree["branch"] as? String,
           !branch.isEmpty {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.output.worktreeBranch", defaultValue: "Worktree branch: %@"),
                branch
            ))
        }
        lines.append(String.localizedStringWithFormat(
            String(localized: "cli.provenance.output.repository", defaultValue: "Repository: %@"),
            explanation.repositoryPath
        ))
        if explanation.attributionSource == "unattributed" {
            lines.append(String(localized: "cli.provenance.output.unattributedNote", defaultValue: "Note: bmux observed this dirty file, but no session has claimed it yet."))
        }
        return lines.joined(separator: "\n")
    }

    private func renderProvenanceContext(_ context: CLIProvenanceContext) -> String {
        if !context.found {
            return [
                String.localizedStringWithFormat(
                    String(localized: "cli.provenance.context.output.notFound", defaultValue: "No provenance context found for %@"),
                    context.repositoryPath
                ),
                context.reason.map {
                    String.localizedStringWithFormat(
                        String(localized: "cli.provenance.output.reason", defaultValue: "Reason: %@"),
                        $0
                    )
                }
            ].compactMap(\.self).joined(separator: "\n")
        }

        let worktreeSummary = [
            context.worktree["branch"] as? String,
            context.worktree["status"] as? String,
            (context.worktree["is_dirty"] as? Bool) == true
                ? String(localized: "cli.provenance.context.output.dirty", defaultValue: "dirty")
                : String(localized: "cli.provenance.context.output.clean", defaultValue: "clean")
        ].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " · ")

        var lines: [String] = [
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.context.output.header", defaultValue: "Provenance context for %@"),
                context.repositoryPath
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.context.output.worktree", defaultValue: "Worktree: %@"),
                worktreeSummary.isEmpty ? context.repositoryPath : worktreeSummary
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.context.output.activeSessions", defaultValue: "Active sessions: %d"),
                context.activeSessions.count
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.context.output.dirtyFiles", defaultValue: "Dirty files: %d"),
                context.dirtyFiles.count
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.context.output.unattributedChanges", defaultValue: "Unattributed changes: %d"),
                context.unattributedChanges.count
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.context.output.recentCheckpoints", defaultValue: "Recent checkpoints: %d"),
                context.recentCheckpoints.count
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.context.output.validationRuns", defaultValue: "Validation runs: %d"),
                context.validationRuns.count
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.context.output.conflicts", defaultValue: "Conflicts: %d"),
                context.conflicts.count
            )
        ]

        appendProvenanceRows(
            context.activeSessions,
            title: String(localized: "cli.provenance.context.output.activeSessionRows", defaultValue: "Active session rows:"),
            to: &lines,
            render: renderProvenanceSessionRow
        )
        appendProvenanceRows(
            context.unattributedChanges,
            title: String(localized: "cli.provenance.context.output.unattributedRows", defaultValue: "Unattributed files:"),
            to: &lines,
            render: renderProvenanceFileRow
        )
        appendProvenanceRows(
            context.conflicts,
            title: String(localized: "cli.provenance.context.output.conflictRows", defaultValue: "Potential file overlaps:"),
            to: &lines,
            render: renderProvenanceConflictRow
        )
        return lines.joined(separator: "\n")
    }

    private func renderProvenanceWorktreeList(_ list: CLIProvenanceWorktreeList) -> String {
        guard !list.worktrees.isEmpty else {
            if let reason = list.reason {
                return reason
            }
            return String(localized: "cli.provenance.worktrees.output.empty", defaultValue: "No provenance worktrees recorded.")
        }
        var lines = [
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.worktrees.output.header", defaultValue: "Known provenance worktrees: %d"),
                list.worktrees.count
            )
        ]
        for row in list.worktrees.prefix(25) {
            let dirty = row.isDirty
                ? String(localized: "cli.provenance.context.output.dirty", defaultValue: "dirty")
                : String(localized: "cli.provenance.context.output.clean", defaultValue: "clean")
            let parts = [row.branch, row.status, dirty].compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }.joined(separator: " · ")
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.worktrees.output.row", defaultValue: "  %@ · %@"),
                row.path,
                parts
            ))
        }
        return lines.joined(separator: "\n")
    }

    private func renderProvenanceSessionTree(_ tree: CLIProvenanceSessionTree) -> String {
        guard tree.found else {
            return [
                String.localizedStringWithFormat(
                    String(localized: "cli.provenance.sessions.output.notFound", defaultValue: "No provenance session tree found for %@"),
                    tree.rootSessionID
                ),
                tree.reason.map {
                    String.localizedStringWithFormat(
                        String(localized: "cli.provenance.output.reason", defaultValue: "Reason: %@"),
                        $0
                    )
                }
            ].compactMap(\.self).joined(separator: "\n")
        }

        var lines = [
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.sessions.output.header", defaultValue: "Session tree for %@"),
                tree.rootSessionID
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.sessions.output.summary", defaultValue: "Sessions: %d · relationships: %d · external identities: %d"),
                tree.sessions.count,
                tree.relationships.count,
                tree.externalIdentities.count
            )
        ]
        for row in tree.sessions.prefix(25) {
            lines.append(renderProvenanceSessionTreeRow(row))
        }
        return lines.joined(separator: "\n")
    }

    private func renderProvenanceLifecycleTraceList(_ list: CLIProvenanceLifecycleTraceList) -> String {
        guard list.found else {
            return [
                String(localized: "cli.provenance.traces.output.empty", defaultValue: "No lifecycle ingestion traces recorded."),
                list.reason.map {
                    String.localizedStringWithFormat(
                        String(localized: "cli.provenance.output.reason", defaultValue: "Reason: %@"),
                        $0
                    )
                }
            ].compactMap(\.self).joined(separator: "\n")
        }

        var lines = [
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.traces.output.header", defaultValue: "Lifecycle ingestion traces: %d"),
                list.runs.count
            )
        ]
        let stagesByRun = Dictionary(grouping: list.stages) { row in
            row["pipeline_run_id"] as? String ?? ""
        }
        for row in list.runs.prefix(20) {
            let pipelineRunID = row["pipeline_run_id"] as? String ?? "?"
            let status = row["status"] as? String ?? "?"
            let stageCount = stagesByRun[pipelineRunID]?.count ?? 0
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.traces.output.row", defaultValue: "  %@ · %@ · stages: %d"),
                pipelineRunID,
                status,
                stageCount
            ))
        }
        return lines.joined(separator: "\n")
    }

    private func renderProvenanceCodexTranscriptImport(
        _ report: CLIProvenanceCodexTranscriptImporter.Report,
        databaseURL: URL
    ) -> String {
        var lines = [
            String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.import.output.header",
                    defaultValue: "Codex transcript import: %d files, %d new events, %d duplicate events"
                ),
                report.filesImported,
                report.eventsAppended,
                report.duplicateEvents
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.import.output.path", defaultValue: "Path: %@"),
                report.path
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.import.output.database", defaultValue: "Database: %@"),
                databaseURL.path
            ),
            String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.import.output.evidence",
                    defaultValue: "Evidence: threads %d · turns %d · prompts %d · commands %d · plans %d · reasoning summaries %d · file changes %d"
                ),
                report.threads,
                report.turns,
                report.prompts,
                report.commands,
                report.plans,
                report.reasoningSummaries,
                report.fileChanges
            ),
            String.localizedStringWithFormat(
                String(localized: "cli.provenance.import.output.skipped", defaultValue: "Skipped files: %d"),
                report.filesSkipped
            )
        ]
        if !report.fileErrors.isEmpty {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.import.output.errors", defaultValue: "Errors: %d"),
                report.fileErrors.count
            ))
            for error in report.fileErrors.prefix(10) {
                lines.append(String.localizedStringWithFormat(
                    String(localized: "cli.provenance.import.output.errorRow", defaultValue: "  %@ · %@"),
                    error.path,
                    error.message
                ))
            }
        }
        return lines.joined(separator: "\n")
    }

    private func renderProvenanceExecutionTelemetryObservationDiagnostic(_ payload: [String: Any]) -> String {
        let sessionID = payload["session_id"] as? String ?? "?"
        let mismatchCount = payload["mismatch_count"] as? Int ?? 0
        guard mismatchCount > 0 else {
            return String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.diagnostics.executionTelemetry.output.matched",
                    defaultValue: "No execution telemetry observation mismatches for %@."
                ),
                sessionID
            )
        }

        var lines = [
            String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.diagnostics.executionTelemetry.output.header",
                    defaultValue: "Execution telemetry observation mismatches for %@: %d"
                ),
                sessionID,
                mismatchCount
            )
        ]
        let mismatches = payload["mismatches"] as? [[String: Any]] ?? []
        for mismatch in mismatches {
            let code = mismatch["code"] as? String ?? "unknown"
            let live = mismatch["live"] as? String ?? "unknown"
            let currentState = mismatch["current_state"] as? String ?? "unknown"
            lines.append(String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.diagnostics.executionTelemetry.output.row",
                    defaultValue: "  %@ (live: %@, current state: %@)"
                ),
                provenanceExecutionTelemetryMismatchDescription(code),
                live,
                currentState
            ))
        }
        return lines.joined(separator: "\n")
    }

    private func renderProvenanceWorkspaceDisplayDiagnostic(_ payload: [String: Any]) -> String {
        let workspaceID = payload["workspace_id"] as? String ?? "?"
        guard payload["found"] as? Bool == true,
              let currentState = payload["current_state"] as? [String: Any] else {
            let reason = payload["reason"] as? String
                ?? String(
                    localized: "cli.provenance.diagnostics.workspaceDisplay.output.missingReason",
                    defaultValue: "missing"
                )
            return [
                String.localizedStringWithFormat(
                    String(
                        localized: "cli.provenance.diagnostics.workspaceDisplay.output.missing",
                        defaultValue: "No workspace display Current State for %@."
                    ),
                    workspaceID
                ),
                String.localizedStringWithFormat(
                    String(localized: "cli.provenance.output.reason", defaultValue: "Reason: %@"),
                    reason
                )
            ].joined(separator: "\n")
        }

        var lines = [
            String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.diagnostics.workspaceDisplay.output.header",
                    defaultValue: "Workspace display Current State for %@"
                ),
                workspaceID
            )
        ]
        if let title = currentState["title"] as? String {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.diagnostics.workspaceDisplay.output.title", defaultValue: "Title: %@"),
                title
            ))
        }
        if let branch = currentState["branch"] as? String {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.diagnostics.workspaceDisplay.output.branch", defaultValue: "Branch: %@"),
                branch
            ))
        }
        if let isDirty = currentState["is_dirty"] as? Bool {
            let dirtyState = isDirty
                ? String(localized: "cli.provenance.diagnostics.workspaceDisplay.output.dirty", defaultValue: "dirty")
                : String(localized: "cli.provenance.diagnostics.workspaceDisplay.output.clean", defaultValue: "clean")
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.diagnostics.workspaceDisplay.output.dirtyState", defaultValue: "Dirty state: %@"),
                dirtyState
            ))
        }
        if let pullRequest = currentState["pull_request"] as? [String: Any],
           let number = pullRequest["number"] as? Int {
            let status = pullRequest["status"] as? String
                ?? String(
                    localized: "cli.provenance.diagnostics.workspaceDisplay.output.unknown",
                    defaultValue: "unknown"
                )
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.diagnostics.workspaceDisplay.output.pullRequest", defaultValue: "Pull request: #%d · %@"),
                number,
                status
            ))
        }
        let tickets = provenanceWorkspaceDisplayTicketLabels(currentState)
        if !tickets.isEmpty {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.diagnostics.workspaceDisplay.output.tickets", defaultValue: "Tickets: %@"),
                tickets.joined(separator: ", ")
            ))
        }
        if let currentDirectory = currentState["current_directory"] as? String {
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.diagnostics.workspaceDisplay.output.currentDirectory", defaultValue: "Current directory: %@"),
                currentDirectory
            ))
        }
        if let latestEvidence = payload["latest_evidence"] as? [String: Any] {
            let unknown = String(
                localized: "cli.provenance.diagnostics.workspaceDisplay.output.unknown",
                defaultValue: "unknown"
            )
            let eventID = latestEvidence["event_id"] as? String ?? unknown
            let sequence = latestEvidence["event_sequence"].map { "\($0)" } ?? unknown
            lines.append(String.localizedStringWithFormat(
                String(localized: "cli.provenance.diagnostics.workspaceDisplay.output.latestEvidence", defaultValue: "Latest evidence: %@ · sequence %@"),
                eventID,
                sequence
            ))
        }
        return lines.joined(separator: "\n")
    }

    private func provenanceExecutionTelemetryMismatchDescription(_ code: String) -> String {
        switch code {
        case "live_snapshot_missing":
            return String(
                localized: "cli.provenance.diagnostics.executionTelemetry.mismatch.liveSnapshotMissing",
                defaultValue: "live projection snapshot is missing"
            )
        case "current_state_context_missing":
            return String(
                localized: "cli.provenance.diagnostics.executionTelemetry.mismatch.currentStateContextMissing",
                defaultValue: "Current State context is missing"
            )
        case "current_state_session_missing":
            return String(
                localized: "cli.provenance.diagnostics.executionTelemetry.mismatch.currentStateSessionMissing",
                defaultValue: "Current State active session is missing"
            )
        case "provider_identity_mismatch":
            return String(
                localized: "cli.provenance.diagnostics.executionTelemetry.mismatch.providerIdentity",
                defaultValue: "provider identity differs"
            )
        case "lifecycle_presence_mismatch":
            return String(
                localized: "cli.provenance.diagnostics.executionTelemetry.mismatch.lifecyclePresence",
                defaultValue: "broad lifecycle presence differs"
            )
        default:
            return String(
                localized: "cli.provenance.diagnostics.executionTelemetry.mismatch.unknown",
                defaultValue: "unknown mismatch"
            )
        }
    }

    private func appendProvenanceRows(
        _ rows: [[String: AnyHashable]],
        title: String,
        to lines: inout [String],
        render: ([String: AnyHashable]) -> String
    ) {
        guard !rows.isEmpty else { return }
        lines.append(title)
        for row in rows.prefix(5) {
            lines.append(render(row))
        }
    }

    private func renderProvenanceSessionRow(_ row: [String: AnyHashable]) -> String {
        let identity = [
            row["id"] as? String,
            row["agent_kind"] as? String,
            row["status"] as? String
        ].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " · ")
        return String.localizedStringWithFormat(
            String(localized: "cli.provenance.context.output.sessionRow", defaultValue: "  %@"),
            identity
        )
    }

    private func renderProvenanceSessionTreeRow(_ row: [String: AnyHashable]) -> String {
        let depth = row["tree_depth"] as? Int ?? 0
        let indent = String(repeating: "  ", count: min(max(depth, 0), 8))
        let identity = [
            row["id"] as? String,
            row["agent_kind"] as? String,
            row["status"] as? String
        ].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " · ")
        return String.localizedStringWithFormat(
            String(localized: "cli.provenance.sessions.output.sessionRow", defaultValue: "%@%@"),
            indent,
            identity
        )
    }

    private func renderProvenanceFileRow(_ row: [String: AnyHashable]) -> String {
        let status = row["status"] as? String ?? "?"
        let path = row["path"] as? String ?? "?"
        let source = row["attribution_source"] as? String ?? "?"
        let confidence = row["attribution_confidence"] as? String ?? "?"
        return String.localizedStringWithFormat(
            String(localized: "cli.provenance.context.output.fileRow", defaultValue: "  %@ %@ · %@/%@"),
            status,
            path,
            source,
            confidence
        )
    }

    private func renderProvenanceConflictRow(_ row: [String: AnyHashable]) -> String {
        let path = row["path"] as? String ?? "?"
        let contributionIDs = row["contribution_ids"] as? String ?? "?"
        return String.localizedStringWithFormat(
            String(localized: "cli.provenance.context.output.conflictRow", defaultValue: "  %@ · contributions %@"),
            path,
            contributionIDs
        )
    }

    private func formattedProvenanceDate(_ timestamp: TimeInterval) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }

    private func provenanceUsage() -> String {
        String(
            localized: "cli.provenance.usage",
            defaultValue: """
            Usage:
              bmux provenance explain <path> [--json]
              bmux provenance context current [--json]
              bmux provenance worktrees list [--json]
              bmux provenance sessions tree <session-id> [--json]
              bmux provenance import codex-transcripts [--path <path>] [--limit <count>] [--database <path>] [--json]
              bmux provenance traces lifecycle-ingestion [--run <pipeline-run-id>] [--parent-session <session-id>] [--child-session <session-id>] [--status <status>] [--json]
              bmux provenance diagnostics workspace-display --workspace <workspace-id> [--database <path>] [--json]
              bmux provenance diagnostics execution-telemetry-live <session-id> [--agent-chat-url <url>] [--repository <path>] [--database <path>] [--json]

            Inspect bmux work provenance without requiring a live app socket.
            """
        )
    }

    func provenanceWorkspaceDisplayDiagnosticPayload(
        workspaceID: String,
        resolvedWorkspaceID: String? = nil,
        databaseURL: URL,
        response: ProvenanceEngineContracts.ProvenanceWorkspaceDisplayResponse
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "diagnostic": "workspace_display_current_state",
            "workspace_id": workspaceID,
            "database": databaseURL.path,
            "found": response.found,
            "status": response.found ? "found" : "missing"
        ]
        if let resolvedWorkspaceID {
            payload["resolved_workspace_id"] = resolvedWorkspaceID
            payload["workspace_id_source"] = "runtime_workspace_list"
        }
        if let reason = response.reason {
            payload["reason"] = reason
        }
        guard let display = response.display else { return payload }

        payload["current_state"] = provenanceWorkspaceDisplayCurrentStatePayload(display)
        payload["latest_evidence"] = provenanceCompactPayload([
            "event_id": display.latestEventID,
            "event_sequence": display.latestEventSequence
        ])
        return payload
    }

    private func provenanceStableWorkspaceIDForRuntimeWorkspace(
        _ workspaceID: String,
        explicitSocketPath: String?,
        processEnv: [String: String],
        cliBundleIdentifier: String?
    ) -> String? {
        let requestedSocketPath: String
        let socketPathSource: CLISocketPathSource
        do {
            if let explicitSocketPath {
                requestedSocketPath = explicitSocketPath
                socketPathSource = .explicitFlag
            } else if let envSocketPath = try CLISocketEnvironment.socketPath(in: processEnv) {
                requestedSocketPath = envSocketPath
                socketPathSource = CLISocketPathResolver.isImplicitDefaultPath(
                    envSocketPath,
                    bundleIdentifier: cliBundleIdentifier,
                    environment: processEnv
                ) ? .implicitDefault : .environment
            } else {
                requestedSocketPath = CLISocketPathResolver.defaultSocketPath(
                    bundleIdentifier: cliBundleIdentifier,
                    environment: processEnv
                )
                socketPathSource = .implicitDefault
            }
        } catch {
            return nil
        }

        let socketPath = CLISocketPathResolver.resolve(
            requestedPath: requestedSocketPath,
            source: socketPathSource,
            environment: processEnv,
            bundleIdentifier: cliBundleIdentifier
        )
        let client = SocketClient(path: socketPath)
        guard let payload = try? client.sendV2(method: "workspace.list") else {
            return nil
        }
        return provenanceStableWorkspaceID(
            fromWorkspaceListPayload: payload,
            matching: workspaceID
        )
    }

    private func provenanceStableWorkspaceID(
        fromWorkspaceListPayload payload: [String: Any],
        matching workspaceID: String
    ) -> String? {
        let requested = workspaceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requested.isEmpty,
              let workspaces = payload["workspaces"] as? [[String: Any]] else {
            return nil
        }
        for workspace in workspaces {
            let candidates = [
                workspace["id"] as? String,
                workspace["ref"] as? String,
                workspace["stable_workspace_id"] as? String,
            ]
            guard candidates.contains(where: { candidate in
                guard let candidate else { return false }
                return candidate.compare(requested, options: [.caseInsensitive]) == .orderedSame
            }) else {
                continue
            }
            let stableWorkspaceID = (workspace["stable_workspace_id"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return stableWorkspaceID?.isEmpty == false ? stableWorkspaceID : nil
        }
        return nil
    }

    private func provenanceWorkspaceDisplayCurrentStatePayload(
        _ display: ProvenanceEngineContracts.ProvenanceWorkspaceDisplayRecord
    ) -> [String: Any] {
        provenanceCompactPayload([
            "id": display.id,
            "workspace_id": display.workspaceID,
            "repository_id": display.repositoryID,
            "worktree_id": display.worktreeID,
            "current_directory": display.currentDirectory,
            "title": display.title,
            "title_source": display.titleSource,
            "branch": display.branch,
            "pull_request": provenanceWorkspaceDisplayPullRequestPayload(display),
            "is_dirty": display.isDirty,
            "ticket_ids": display.ticketIDs,
            "ticket_links": provenanceWorkspaceDisplayTicketLinksPayload(display.ticketLinks),
            "observed_at": formattedProvenanceDate(display.observedAt.timeIntervalSince1970),
            "updated_at": formattedProvenanceDate(display.updatedAt.timeIntervalSince1970)
        ])
    }

    private func provenanceWorkspaceDisplayPullRequestPayload(
        _ display: ProvenanceEngineContracts.ProvenanceWorkspaceDisplayRecord
    ) -> [String: Any]? {
        guard display.pullRequestNumber != nil
              || display.pullRequestURL != nil
              || display.pullRequestStatus != nil
              || display.pullRequestBranch != nil else {
            return nil
        }
        let payload = provenanceCompactPayload([
            "number": display.pullRequestNumber,
            "url": display.pullRequestURL,
            "status": display.pullRequestStatus,
            "branch": display.pullRequestBranch,
            "is_stale": display.pullRequestIsStale
        ])
        return payload.isEmpty ? nil : payload
    }

    private func provenanceWorkspaceDisplayTicketLinksPayload(
        _ ticketLinks: [ProvenanceEngineContracts.ProvenanceWorkspaceDisplayTicketLinkRecord]
    ) -> [[String: Any]] {
        ticketLinks.map { ticketLink in
            provenanceCompactPayload([
                "id": ticketLink.id, "system": ticketLink.system,
                "title": ticketLink.title,
                "url": ticketLink.url
            ])
        }
    }

    private func provenanceWorkspaceDisplayTicketLabels(_ currentState: [String: Any]) -> [String] {
        let ticketLinks = currentState["ticket_links"] as? [[String: Any]] ?? []
        let linkedLabels = ticketLinks.compactMap { ticketLink -> String? in
            guard let id = ticketLink["id"] as? String else { return nil }
            guard let url = ticketLink["url"] as? String, !url.isEmpty else { return id }
            return "\(id) <\(url)>"
        }
        if !linkedLabels.isEmpty {
            return linkedLabels
        }
        return currentState["ticket_ids"] as? [String] ?? []
    }

    private func provenanceCompactPayload(_ values: [String: Any?]) -> [String: Any] {
        values.reduce(into: [String: Any]()) { partial, item in
            if let value = item.value {
                partial[item.key] = value
            }
        }
    }

    func provenanceExecutionTelemetryObservationDiagnosticPayload(
        sessionID: String,
        livePayload: ExecutionTelemetryLiveProjectionReadPayload,
        currentContext: ProvenanceEngineContracts.ProvenanceCurrentContextResponse
    ) -> [String: Any] {
        let diagnostic = ExecutionTelemetryObservationDiagnostic.compare(
            sessionID: sessionID,
            livePayload: livePayload,
            currentStateFound: currentContext.found,
            currentStateSessions: currentContext.activeSessions.map { row in
                ExecutionTelemetryObservationCurrentStateSession(
                    sessionID: row.session.id,
                    provider: row.session.agentKind,
                    lifecycleStatus: row.session.status
                )
            }
        )

        return [
            "session_id": diagnostic.sessionID,
            "status": diagnostic.status,
            "mismatch_count": diagnostic.mismatches.count,
            "mismatches": diagnostic.mismatches.map { mismatch in
                [
                    "code": mismatch.code,
                    "live": mismatch.live,
                    "current_state": mismatch.currentState
                ]
            }
        ]
    }
}
