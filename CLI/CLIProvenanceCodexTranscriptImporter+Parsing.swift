import Foundation

extension CLIProvenanceCodexTranscriptImporter {
    func transcriptLines(at url: URL) throws -> [TranscriptLine] {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ImportError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.import.error.invalidUTF8",
                    defaultValue: "Codex transcript is not valid UTF-8: %@"
                ),
                url.path
            ))
        }
        return try text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .compactMap { index, lineText -> TranscriptLine? in
                try transcriptLine(from: String(lineText), lineNumber: index + 1, path: url.path)
            }
    }

    func transcriptLine(from lineText: String, lineNumber: Int, path: String) throws -> TranscriptLine? {
        let trimmed = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let data = Data(trimmed.utf8)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = Self.dictionary(object["payload"]) else {
            throw ImportError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.import.error.invalidJSONLine",
                    defaultValue: "Codex transcript line is not a JSON object: %@:%d"
                ),
                path,
                lineNumber
            ))
        }
        return TranscriptLine(
            lineNumber: lineNumber,
            ordinal: Self.int(object["ordinal"]),
            type: Self.string(object["type"]) ?? "",
            timestamp: Self.dateFromString(Self.string(object["timestamp"])),
            payload: payload
        )
    }

    func sessionMetadata(from lines: [TranscriptLine]) -> TranscriptMetadata? {
        for line in lines where line.type == "session_meta" {
            guard let sessionID = Self.trimmedNonEmpty(Self.firstNonEmpty(
                Self.string(line.payload["session_id"]),
                Self.string(line.payload["id"])
            )) else {
                continue
            }
            return TranscriptMetadata(
                line: line,
                sessionID: sessionID,
                providerThreadID: sessionID,
                cwd: Self.trimmedNonEmpty(Self.string(line.payload["cwd"])),
                timestamp: Self.dateFromString(Self.string(line.payload["timestamp"])) ?? line.timestamp ?? Date(timeIntervalSince1970: 0),
                model: Self.trimmedNonEmpty(Self.string(line.payload["model"]))
                    ?? Self.trimmedNonEmpty(Self.string(line.payload["model_provider"]))
            )
        }
        return nil
    }

    static func planUpdate(from payload: [String: Any]) -> PlanUpdate? {
        guard let arguments = parsedArguments(from: payload["arguments"]) ?? dictionary(payload["parsed_arguments"]) else {
            return nil
        }
        let rawSteps = arrayOfDictionaries(arguments["plan"]) ?? arrayOfDictionaries(arguments["steps"]) ?? []
        let steps = rawSteps.compactMap { item -> PlanStep? in
            guard let text = trimmedNonEmpty(firstNonEmpty(string(item["step"]), string(item["text"]))) else {
                return nil
            }
            return PlanStep(text: text, status: trimmedNonEmpty(string(item["status"])) ?? "unknown")
        }
        guard !steps.isEmpty else { return nil }
        return PlanUpdate(explanation: trimmedNonEmpty(string(arguments["explanation"])), steps: steps)
    }

    static func messageText(from payload: [String: Any]) -> String? {
        if let text = trimmedNonEmpty(string(payload["text"])) {
            return text
        }
        return textFragments(from: payload["content"]).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    static func reasoningText(from payload: [String: Any]) -> String? {
        if let text = trimmedNonEmpty(string(payload["text"])) {
            return text
        }
        if let text = trimmedNonEmpty(string(payload["summary_text"])) {
            return text
        }
        let summaryText = textFragments(from: payload["summary_text"]).joined(separator: "\n")
        if let text = trimmedNonEmpty(summaryText) {
            return text
        }
        let summary = textFragments(from: payload["summary"]).joined(separator: "\n")
        return trimmedNonEmpty(summary)
    }

    static func textFragments(from value: Any?) -> [String] {
        if let text = trimmedNonEmpty(string(value)) {
            return [text]
        }
        if let array = value as? [Any] {
            return array.flatMap(textFragments(from:))
        }
        if let dictionary = dictionary(value) {
            return [
                string(dictionary["text"]),
                string(dictionary["content"]),
                string(dictionary["summary_text"])
            ]
            .compactMap(trimmedNonEmpty)
            + textFragments(from: dictionary["summary"])
        }
        return []
    }

    static func commandText(from item: [String: Any]) -> String? {
        if let argv = item["command"] as? [String], !argv.isEmpty {
            return argv.map(shellQuote).joined(separator: " ")
        }
        if let argv = item["command"] as? [Any] {
            let values = argv.compactMap(string)
            if !values.isEmpty {
                return values.map(shellQuote).joined(separator: " ")
            }
        }
        return trimmedNonEmpty(string(item["command"]))
    }

    static func shellQuote(_ value: String) -> String {
        if value.range(of: #"^[A-Za-z0-9_@%+=:,./-]+$"#, options: .regularExpression) != nil {
            return value
        }
        return "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    static func commandStatus(status: String?, exitCode: Int?) -> String {
        guard let status = trimmedNonEmpty(status)?.lowercased() else {
            return exitCode.map { $0 == 0 ? "succeeded" : "failed" } ?? "unknown"
        }
        if status == "completed" {
            return exitCode.map { $0 == 0 ? "succeeded" : "failed" } ?? "completed"
        }
        return status
    }

    static func patchFileChanges(from patch: String) -> [PatchFileChange] {
        var changes: [PatchFileChange] = []
        for line in patch.components(separatedBy: .newlines) {
            if let path = patchPath(line, marker: "*** Add File:") {
                changes.append(PatchFileChange(path: path, status: "added"))
            } else if let path = patchPath(line, marker: "*** Delete File:") {
                changes.append(PatchFileChange(path: path, status: "deleted"))
            } else if let path = patchPath(line, marker: "*** Update File:") {
                changes.append(PatchFileChange(path: path, status: "modified"))
            } else if let path = patchPath(line, marker: "*** Move to:") {
                changes.append(PatchFileChange(path: path, status: "renamed"))
            }
        }
        var seen: Set<String> = []
        return changes.filter { change in
            let key = "\(change.status)\n\(change.path)"
            return seen.insert(key).inserted
        }
    }

    static func patchPath(_ line: String, marker: String) -> String? {
        guard line.hasPrefix(marker) else { return nil }
        return trimmedNonEmpty(String(line.dropFirst(marker.count)))
    }

    static func repositoryRelativePath(_ path: String, gitContext: GitContext?) -> String {
        guard path.hasPrefix("/"),
              let root = gitContext?.worktree.path else {
            return path
        }
        let normalizedRoot = URL(fileURLWithPath: root, isDirectory: true).standardizedFileURL.path
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        let prefix = normalizedRoot.hasSuffix("/") ? normalizedRoot : "\(normalizedRoot)/"
        guard normalizedPath.hasPrefix(prefix) else { return normalizedPath }
        return String(normalizedPath.dropFirst(prefix.count))
    }

    static func parsedArguments(from value: Any?) -> [String: Any]? {
        if let dictionary = dictionary(value) {
            return dictionary
        }
        guard let text = trimmedNonEmpty(string(value)),
              let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    static func turnID(from payload: [String: Any]) -> String? {
        let metadata = dictionary(payload["internal_chat_message_metadata_passthrough"])
        return firstNonEmpty(
            string(payload["turn_id"]),
            string(metadata?["turn_id"])
        )
    }

    static func dateFromMilliseconds(_ value: Any?) -> Date? {
        double(value).map { Date(timeIntervalSince1970: $0 / 1_000) }
    }

    static func dateFromSeconds(_ value: Any?) -> Date? {
        double(value).map { Date(timeIntervalSince1970: $0) }
    }

    static func dateFromString(_ value: String?) -> Date? {
        guard let value = trimmedNonEmpty(value) else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }

    static func isDuplicateAppendError(_ error: Error) -> Bool {
        let description = String(describing: error).lowercased()
        return description.contains("provenance_events")
            && (description.contains("unique") || description.contains("constraint") || description.contains("duplicate"))
    }

    static func dictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    static func arrayOfDictionaries(_ value: Any?) -> [[String: Any]]? {
        if let dictionaries = value as? [[String: Any]] {
            return dictionaries
        }
        return (value as? [Any])?.compactMap(dictionary)
    }

    static func string(_ value: Any?) -> String? {
        value as? String
    }

    static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value) }
        if let value = string(value) { return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    static func double(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = string(value) { return Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            if let value = trimmedNonEmpty(value) {
                return value
            }
        }
        return nil
    }

    static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    static func bounded(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit))
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
