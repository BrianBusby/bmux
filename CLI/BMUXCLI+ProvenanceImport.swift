import Foundation

extension BMUXCLI {
    func runProvenanceImport(commandArgs: [String], jsonOutput: Bool) async throws {
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

    func provenanceImportLimit(_ value: String?, commandName: String) throws -> Int? {
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

    func printProvenanceCodexTranscriptImport(
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

    func renderProvenanceCodexTranscriptImport(
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
}
