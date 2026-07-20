import Foundation

extension BMUXCLI {
    func runProvenanceCommand(commandArgs: [String], jsonOutput: Bool) async throws {
        let subcommand = commandArgs.first?.lowercased()
        switch subcommand {
        case "explain":
            try runProvenanceExplain(
                commandArgs: Array(commandArgs.dropFirst()),
                jsonOutput: jsonOutput
            )
        case "context":
            try runProvenanceContext(
                commandArgs: Array(commandArgs.dropFirst()),
                jsonOutput: jsonOutput
            )
        case "worktrees":
            try runProvenanceWorktrees(
                commandArgs: Array(commandArgs.dropFirst()),
                jsonOutput: jsonOutput
            )
        case "sessions":
            try await runProvenanceSessions(
                commandArgs: Array(commandArgs.dropFirst()),
                jsonOutput: jsonOutput
            )
        case "traces":
            try runProvenanceTraces(
                commandArgs: Array(commandArgs.dropFirst()),
                jsonOutput: jsonOutput
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

    private func runProvenanceExplain(commandArgs: [String], jsonOutput: Bool) throws {
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

        let databaseURL = provenanceDatabaseURL(databasePath: databasePath)
        let target = try CLIProvenanceGitResolver().resolve(path: path, commandLabel: commandName)
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
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

        let reader = try CLIProvenanceSQLiteReader(databaseURL: databaseURL)
        let explanation = try reader.explain(target: target)
        printProvenanceExplanation(explanation, jsonOutput: jsonOutput)
    }

    private func runProvenanceContext(commandArgs: [String], jsonOutput: Bool) throws {
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
        let databaseURL = provenanceDatabaseURL(databasePath: databasePath)
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
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

        let reader = try CLIProvenanceSQLiteReader(databaseURL: databaseURL)
        let context = try reader.context(target: target)
        printProvenanceContext(context, jsonOutput: jsonOutput)
    }

    private func runProvenanceWorktrees(commandArgs: [String], jsonOutput: Bool) throws {
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

        let databaseURL = provenanceDatabaseURL(databasePath: databasePath)
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            let list = CLIProvenanceWorktreeList(
                worktrees: [],
                reason: String(localized: "cli.provenance.reason.noDatabase", defaultValue: "no provenance database exists yet")
            )
            printProvenanceWorktreeList(list, jsonOutput: jsonOutput)
            return
        }

        let reader = try CLIProvenanceSQLiteReader(databaseURL: databaseURL)
        let list = try reader.worktreeList()
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

        let databaseURL = provenanceDatabaseURL(databasePath: databasePath)
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
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

        let client: any ProvenanceEngineClient = try WorkProvenanceStore(databaseURL: databaseURL)
        let response = try await client.sessionTree(ProvenanceSessionTreeRequest(
            rootSessionID: sessionID,
            limit: 100
        ))
        let tree = CLIProvenanceSessionTree(
            response: response,
            noSessionReason: String(localized: "cli.provenance.reason.noSession", defaultValue: "no provenance has been recorded for this session"),
            externalIdentityLimit: 200
        )
        printProvenanceSessionTree(tree, jsonOutput: jsonOutput)
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

    private func provenanceDatabaseURL(databasePath: String?) -> URL {
        if let databasePath = databasePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !databasePath.isEmpty {
            return URL(fileURLWithPath: NSString(string: databasePath).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
            .appendingPathComponent("bmux", isDirectory: true)
            .appendingPathComponent("work-provenance", isDirectory: true)
            .appendingPathComponent("bmux-work-provenance.sqlite", isDirectory: false)
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
              bmux provenance traces lifecycle-ingestion [--run <pipeline-run-id>] [--parent-session <session-id>] [--child-session <session-id>] [--status <status>] [--json]

            Inspect bmux work provenance without requiring a live app socket.
            """
        )
    }
}
