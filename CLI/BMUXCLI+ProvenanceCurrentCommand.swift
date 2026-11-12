import Foundation
import ProvenanceEngineContracts

extension BMUXCLI {
    func runProvenanceRelatedCurrent(
        commandArgs: [String], jsonOutput: Bool,
        explicitSocketPath: String?, explicitSocketPassword: String?,
        processEnv: [String: String], cliBundleIdentifier: String?
    ) async throws {
        let (databasePath, argsAfterDatabase) = parseOption(commandArgs, name: "--database")
        let (limitText, remaining) = parseOption(argsAfterDatabase, name: "--limit")
        guard remaining == ["--current"] else { throw CLIError(message: provenanceSessionsRelatedUsage()) }
        if let databasePath, databasePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw CLIError(message: String.localizedStringWithFormat(
                String(localized: "cli.provenance.error.optionRequiresValue", defaultValue: "%@: %@ requires a value"),
                "provenance sessions related", "--database"
            ))
        }
        let limit: Int
        if let limitText {
            guard let parsed = Int(limitText), (1...5).contains(parsed) else {
                throw CLIError(message: String(localized: "cli.provenance.current.invalidLimit", defaultValue: "--limit must be an integer from 1 through 5"))
            }
            limit = parsed
        } else {
            limit = 5
        }
        let socketPath = try provenanceSocketPath(
            explicitSocketPath: explicitSocketPath, processEnv: processEnv, cliBundleIdentifier: cliBundleIdentifier
        )
        let socket = SocketClient(path: socketPath)
        defer { socket.close() }
        do {
            try socket.connect()
            try authenticateClientIfNeeded(socket, explicitPassword: explicitSocketPassword, socketPath: socketPath)
        } catch {
            printProvenanceCurrentUnavailable("app_linkage_unavailable", jsonOutput: jsonOutput)
            return
        }
        let identity = provenanceCallerIdentity(client: socket, environment: processEnv)
        guard case let .available(workspaceID, surfaceID, providerSessionID) = identity else {
            if case let .unavailable(reason) = identity { printProvenanceCurrentUnavailable(reason, jsonOutput: jsonOutput) }
            return
        }
        let databaseURL = provenanceDatabaseOverrideURL(databasePath: databasePath)
            ?? WorkProvenanceStorageLocation(homeDirectory: WorkProvenanceStorageLocation.defaultHomeDirectory()).databaseURL
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            printProvenanceCurrentUnavailable("no_database", jsonOutput: jsonOutput)
            return
        }
        let (client, _) = try provenanceEngineClient(databasePath: databasePath)
        let association = try await client.workspaceCodingAgentSessionAssociation(.init(
            workspaceID: workspaceID, surfaceID: surfaceID, providerSessionID: providerSessionID
        ))
        guard let sessionID = association.association?.sessionID, association.found else {
            printProvenanceCurrentUnavailable(association.reason ?? "no_canonical_association", jsonOutput: jsonOutput)
            return
        }
        let response = try await client.relatedSessions(.init(targetSessionID: sessionID, limit: limit, exclusionLimit: 10))
        guard provenanceCallerIdentity(client: socket, environment: processEnv) == identity else {
            printProvenanceCurrentUnavailable("caller_changed", jsonOutput: jsonOutput)
            return
        }
        try printProvenanceCurrentRelated(response, jsonOutput: jsonOutput)
    }

    func printProvenanceCurrentUnavailable(_ reason: String, jsonOutput: Bool) {
        if jsonOutput {
            var response: [String: Any] = ["found": false, "reason": reason, "retryable": true]
            if reason == "ambiguous_caller" { response["recovery"] = "start_fresh_pane" }
            print(jsonString(response))
        } else if reason == "ambiguous_caller" {
            print(String(localized: "cli.provenance.current.ambiguous", defaultValue: "Current session context is ambiguous. Start Codex in a fresh pane and retry."))
        } else {
            print(String.localizedStringWithFormat(
                String(localized: "cli.provenance.current.unavailable", defaultValue: "Current session context is unavailable (%@). Wait for session linkage and retry; verify this command runs inside the intended Codex pane."),
                reason
            ))
        }
    }
}
