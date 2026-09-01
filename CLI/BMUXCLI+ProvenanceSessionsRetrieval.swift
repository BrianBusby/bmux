import Foundation
import ProvenanceEngineContracts

extension BMUXCLI {
    func runProvenanceSessions(commandArgs: [String], jsonOutput: Bool) async throws {
        let (databasePath, routedArgs) = parseOption(commandArgs, name: "--database")
        let databaseArgs = databasePath.map { ["--database", $0] } ?? []
        switch routedArgs.first?.lowercased() {
        case "tree":
            try await runProvenanceSessionsTree(commandArgs: commandArgs, jsonOutput: jsonOutput)
        case "related":
            try await runProvenanceSessionsRelated(
                commandArgs: Array(routedArgs.dropFirst()) + databaseArgs,
                jsonOutput: jsonOutput
            )
        case "collisions":
            try await runProvenanceSessionsCollisions(
                commandArgs: Array(routedArgs.dropFirst()) + databaseArgs,
                jsonOutput: jsonOutput
            )
        case "help", "--help", "-h":
            print(provenanceSessionsUsage())
        default:
            throw CLIError(message: provenanceSessionsUsage())
        }
    }

    func runProvenanceSessionsRelated(
        commandArgs: [String],
        jsonOutput: Bool
    ) async throws {
        if provenanceRetrievalRequestedHelp(commandArgs) {
            print(provenanceSessionsRelatedUsage())
            return
        }
        let commandName = "provenance sessions related"
        let parsed = try parseProvenanceRetrievalOptions(
            commandArgs,
            commandName: commandName,
            allowedOptions: [
                "--database",
                "--exclusion-limit",
                "--limit",
                "--revision",
                "--updated-after",
            ]
        )
        guard let sessionID = try parsed.singleSessionID(usage: provenanceSessionsRelatedUsage()) else { return }
        let limit = try provenanceRetrievalInteger(
            parsed.value(for: "--limit"),
            option: "--limit",
            defaultValue: 10,
            validRange: 0...25,
            commandName: commandName
        )
        let exclusionLimit = try provenanceRetrievalInteger(
            parsed.value(for: "--exclusion-limit"),
            option: "--exclusion-limit",
            defaultValue: 10,
            validRange: 0...50,
            commandName: commandName
        )
        let updatedAfter = try provenanceRetrievalDate(
            parsed.value(for: "--updated-after"),
            option: "--updated-after",
            commandName: commandName
        )
        let revisionID = provenanceRetrievalTrimmedValue(parsed.value(for: "--revision"))
        let databasePath = provenanceRetrievalTrimmedValue(parsed.value(for: "--database"))

        let response: ProvenanceRelatedSessionResponse
        if !provenanceRetrievalDatabaseExists(databasePath: databasePath) {
            response = ProvenanceRelatedSessionResponse(
                found: false,
                reason: "no_database",
                targetSessionID: sessionID,
                projection: nil
            )
        } else {
            let (client, _) = try provenanceEngineClient(databasePath: databasePath)
            response = try await client.relatedSessions(ProvenanceRelatedSessionRequest(
                targetSessionID: sessionID,
                limit: limit,
                updatedAfter: updatedAfter,
                revisionID: revisionID,
                exclusionLimit: exclusionLimit
            ))
        }
        printProvenanceRelatedSessions(response, jsonOutput: jsonOutput)
    }

    func runProvenanceSessionsCollisions(
        commandArgs: [String],
        jsonOutput: Bool
    ) async throws {
        if provenanceRetrievalRequestedHelp(commandArgs) {
            print(provenanceSessionsCollisionsUsage())
            return
        }
        let commandName = "provenance sessions collisions"
        let parsed = try parseProvenanceRetrievalOptions(
            commandArgs,
            commandName: commandName,
            allowedOptions: [
                "--artifact-path",
                "--database",
                "--exclusion-limit",
                "--limit",
                "--related-session-limit",
                "--revision",
                "--stale-before",
                "--updated-after",
            ]
        )
        guard let sessionID = try parsed.singleSessionID(usage: provenanceSessionsCollisionsUsage()) else { return }
        let limit = try provenanceRetrievalInteger(
            parsed.value(for: "--limit"),
            option: "--limit",
            defaultValue: 10,
            validRange: 0...25,
            commandName: commandName
        )
        let relatedSessionLimit = try provenanceRetrievalInteger(
            parsed.value(for: "--related-session-limit"),
            option: "--related-session-limit",
            defaultValue: 50,
            validRange: 0...100,
            commandName: commandName
        )
        let exclusionLimit = try provenanceRetrievalInteger(
            parsed.value(for: "--exclusion-limit"),
            option: "--exclusion-limit",
            defaultValue: 10,
            validRange: 0...50,
            commandName: commandName
        )
        let artifactPath = try provenanceRetrievalArtifactPath(
            parsed.value(for: "--artifact-path"),
            commandName: commandName
        )
        let updatedAfter = try provenanceRetrievalDate(
            parsed.value(for: "--updated-after"),
            option: "--updated-after",
            commandName: commandName
        )
        let staleBefore = try provenanceRetrievalDate(
            parsed.value(for: "--stale-before"),
            option: "--stale-before",
            commandName: commandName
        )
        let revisionID = provenanceRetrievalTrimmedValue(parsed.value(for: "--revision"))
        let databasePath = provenanceRetrievalTrimmedValue(parsed.value(for: "--database"))

        let response: ProvenanceArtifactCollisionResponse
        if !provenanceRetrievalDatabaseExists(databasePath: databasePath) {
            response = ProvenanceArtifactCollisionResponse(
                found: false,
                reason: "no_database",
                targetSessionID: sessionID,
                projection: nil
            )
        } else {
            let (client, _) = try provenanceEngineClient(databasePath: databasePath)
            response = try await client.artifactCollisions(ProvenanceArtifactCollisionRequest(
                targetSessionID: sessionID,
                limit: limit,
                artifactPath: artifactPath,
                updatedAfter: updatedAfter,
                staleBefore: staleBefore,
                revisionID: revisionID,
                relatedSessionLimit: relatedSessionLimit,
                exclusionLimit: exclusionLimit
            ))
        }
        printProvenanceArtifactCollisions(response, jsonOutput: jsonOutput)
    }

    func provenanceSessionsRelatedUsage() -> String {
        String(
            localized: "cli.provenance.sessions.related.usage",
            defaultValue: "Usage: bmux provenance sessions related <pe-session-id> [--limit <count>] [--exclusion-limit <count>] [--updated-after <timestamp>] [--revision <revision-id>] [--database <path>] [--json]"
        )
    }

    func provenanceSessionsUsage() -> String {
        String(
            localized: "cli.provenance.sessions.usage",
            defaultValue: "Usage: bmux provenance sessions <tree|related|collisions> [...]"
        )
    }

    func provenanceSessionsCollisionsUsage() -> String {
        String(
            localized: "cli.provenance.sessions.collisions.usage",
            defaultValue: "Usage: bmux provenance sessions collisions <pe-session-id> [--limit <count>] [--related-session-limit <count>] [--exclusion-limit <count>] [--artifact-path <repo-relative-path>] [--updated-after <timestamp>] [--stale-before <timestamp>] [--revision <revision-id>] [--database <path>] [--json]"
        )
    }
}

private struct ProvenanceRetrievalParsedOptions {
    let values: [String: String]
    let positionals: [String]

    func value(for option: String) -> String? {
        values[option]
    }

    func singleSessionID(usage: String) throws -> String? {
        guard let raw = positionals.first else {
            throw CLIError(message: usage)
        }
        let sessionID = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sessionID.isEmpty else {
            throw CLIError(message: usage)
        }
        guard positionals.count == 1 else {
            throw CLIError(message: usage)
        }
        return sessionID
    }
}

private extension BMUXCLI {
    func provenanceRetrievalRequestedHelp(_ args: [String]) -> Bool {
        guard args.count == 1 else { return false }
        return ["help", "--help", "-h"].contains(args[0].lowercased())
    }

    func parseProvenanceRetrievalOptions(
        _ args: [String],
        commandName: String,
        allowedOptions: Set<String>
    ) throws -> ProvenanceRetrievalParsedOptions {
        var values: [String: String] = [:]
        var positionals: [String] = []
        var index = 0
        while index < args.count {
            let arg = args[index]
            if arg == "--" {
                positionals.append(contentsOf: args.dropFirst(index + 1))
                break
            }
            if arg.hasPrefix("--") {
                let name: String
                let value: String
                if let equals = arg.firstIndex(of: "=") {
                    name = String(arg[..<equals])
                    guard allowedOptions.contains(name) else {
                        try rejectProvenanceUnknownFlags([name], commandName: commandName)
                        index += 1
                        continue
                    }
                    value = String(arg[arg.index(after: equals)...])
                    guard !value.isEmpty else {
                        throw CLIError(message: provenanceRetrievalMissingValueMessage(
                            commandName: commandName,
                            option: name
                        ))
                    }
                } else {
                    name = arg
                    guard allowedOptions.contains(name) else {
                        try rejectProvenanceUnknownFlags([name], commandName: commandName)
                        index += 1
                        continue
                    }
                    guard index + 1 < args.count,
                          !args[index + 1].hasPrefix("--") else {
                        throw CLIError(message: provenanceRetrievalMissingValueMessage(
                            commandName: commandName,
                            option: name
                        ))
                    }
                    value = args[index + 1]
                    index += 1
                }
                guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw CLIError(message: provenanceRetrievalMissingValueMessage(
                        commandName: commandName,
                        option: name
                    ))
                }
                values[name] = value
            } else {
                positionals.append(arg)
            }
            index += 1
        }
        return ProvenanceRetrievalParsedOptions(values: values, positionals: positionals)
    }

    func provenanceRetrievalInteger(
        _ value: String?,
        option: String,
        defaultValue: Int,
        validRange: ClosedRange<Int>,
        commandName: String
    ) throws -> Int {
        guard let trimmed = provenanceRetrievalTrimmedValue(value) else { return defaultValue }
        guard let parsed = Int(trimmed), validRange.contains(parsed) else {
            throw CLIError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.error.invalidIntegerRange",
                    defaultValue: "%@: %@ must be an integer from %d through %d"
                ),
                commandName,
                option,
                validRange.lowerBound,
                validRange.upperBound
            ))
        }
        return parsed
    }

    func provenanceRetrievalDate(
        _ value: String?,
        option: String,
        commandName: String
    ) throws -> Date? {
        guard let trimmed = provenanceRetrievalTrimmedValue(value) else { return nil }
        if let seconds = Double(trimmed), seconds.isFinite {
            return Date(timeIntervalSince1970: seconds)
        }
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = fractionalFormatter.date(from: trimmed) {
            return parsed
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let parsed = formatter.date(from: trimmed) {
            return parsed
        }
        throw CLIError(message: String.localizedStringWithFormat(
            String(
                localized: "cli.provenance.error.invalidTimestamp",
                defaultValue: "%@: %@ must be RFC 3339 like 2026-08-31T05:44:25Z or Unix epoch seconds"
            ),
            commandName,
            option
        ))
    }

    func provenanceRetrievalArtifactPath(_ value: String?, commandName: String) throws -> String? {
        guard let trimmed = provenanceRetrievalTrimmedValue(value) else { return nil }
        guard !trimmed.hasPrefix("/"),
              !trimmed.contains("\0") else {
            throw CLIError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.sessions.collisions.error.invalidArtifactPath",
                    defaultValue: "%@: --artifact-path must be a non-empty repository-relative path"
                ),
                commandName
            ))
        }
        return trimmed
    }

    func provenanceRetrievalTrimmedValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    func provenanceRetrievalMissingValueMessage(commandName: String, option: String) -> String {
        String.localizedStringWithFormat(
            String(
                localized: "cli.provenance.error.optionRequiresValue",
                defaultValue: "%@: %@ requires a value"
            ),
            commandName,
            option
        )
    }

    func provenanceRetrievalDatabaseExists(databasePath: String?) -> Bool {
        FileManager.default.fileExists(atPath: provenanceRetrievalDatabaseURL(databasePath: databasePath).path)
    }

    func provenanceRetrievalDatabaseURL(databasePath: String?) -> URL {
        if let databasePath = provenanceRetrievalTrimmedValue(databasePath) {
            return URL(fileURLWithPath: NSString(string: databasePath).expandingTildeInPath)
        }
        let homeDirectory = WorkProvenanceStorageLocation.defaultHomeDirectory()
        return WorkProvenanceStorageLocation(homeDirectory: homeDirectory).databaseURL
    }

    func printProvenanceRelatedSessions(
        _ response: ProvenanceRelatedSessionResponse,
        jsonOutput: Bool
    ) {
        if jsonOutput {
            print(jsonString(provenanceRetrievalPayload(response)))
            return
        }
        print(renderProvenanceRelatedSessions(response))
    }

    func printProvenanceArtifactCollisions(
        _ response: ProvenanceArtifactCollisionResponse,
        jsonOutput: Bool
    ) {
        if jsonOutput {
            print(jsonString(provenanceRetrievalPayload(response)))
            return
        }
        print(renderProvenanceArtifactCollisions(response))
    }

    func provenanceRetrievalPayload<Response: Encodable>(_ response: Response) -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(response),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [
                "found": false,
                "reason": "encoding_failed",
            ]
        }
        return object
    }
}
