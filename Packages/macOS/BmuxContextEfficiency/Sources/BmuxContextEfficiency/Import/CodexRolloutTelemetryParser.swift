import Foundation

struct CodexRolloutTelemetryParser: Sendable {
    static let parserVersion = 1

    private let tokenUsageExtractor: CodexTokenUsageExtractor
    private let commandSummary: CodexRolloutCommandSummary

    init(
        tokenUsageExtractor: CodexTokenUsageExtractor = CodexTokenUsageExtractor(),
        commandSummary: CodexRolloutCommandSummary = CodexRolloutCommandSummary()
    ) {
        self.tokenUsageExtractor = tokenUsageExtractor
        self.commandSummary = commandSummary
    }

    func parse(line: CodexRolloutImportedLine, fallbackThreadID: String) -> CodexRolloutParsedEvent {
        if let parserErrorMessage = line.parserErrorMessage {
            return parserError(line: line, fallbackThreadID: fallbackThreadID, message: parserErrorMessage)
        }
        guard let data = line.text.data(using: .utf8) else {
            return parserError(line: line, fallbackThreadID: fallbackThreadID, message: "line is not UTF-8")
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return parserError(line: line, fallbackThreadID: fallbackThreadID, message: "line is not valid JSON")
        }

        let payload = dictionaryPayload(from: object["payload"])
        let rolloutType = object["type"] as? String
        let payloadType = payload?["type"] as? String
        let threadID = threadID(from: object, payload: payload) ?? fallbackThreadID
        let timestamp = timestamp(from: object) ?? payload.flatMap(timestamp)
        let tokenUsage = tokenUsageExtractor.extract(from: object)
        let kind = eventKind(rolloutType: rolloutType, payloadType: payloadType, tokenUsage: tokenUsage)

        return CodexRolloutParsedEvent(
            kind: kind,
            rolloutType: rolloutType,
            payloadType: payloadType,
            threadID: threadID,
            timestamp: timestamp,
            sourceReference: line.sourceReference,
            tokenUsage: tokenUsage,
            toolCall: toolCall(from: payload, payloadType: payloadType),
            toolOutput: toolOutput(from: payload, payloadType: payloadType),
            parserErrorMessage: rolloutType == nil ? "missing rollout event type" : nil,
            model: stringValue(for: ["model"], in: [object, payload]),
            reasoningEffort: stringValue(for: ["reasoning_effort", "reasoningEffort", "reasoning"], in: [object, payload]),
            cwd: stringValue(for: ["cwd", "working_directory", "workingDirectory"], in: [object, payload])
        )
    }

    private func dictionaryPayload(from value: Any?) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            return dictionary
        }
        if let array = value as? [Any] {
            return dictionaryPayload(from: array)
        }
        guard let string = value as? String,
              let data = string.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return dictionaryPayload(from: object)
    }

    private func dictionaryPayload(from array: [Any]) -> [String: Any]? {
        var firstDictionary: [String: Any]?
        for value in array {
            guard let dictionary = dictionaryPayload(from: value) else {
                continue
            }
            if firstDictionary == nil {
                firstDictionary = dictionary
            }
            if dictionary["type"] is String {
                return dictionary
            }
        }
        return firstDictionary
    }

    private func parserError(
        line: CodexRolloutImportedLine,
        fallbackThreadID: String,
        message: String
    ) -> CodexRolloutParsedEvent {
        CodexRolloutParsedEvent(
            kind: .parserErrorObserved,
            rolloutType: nil,
            payloadType: nil,
            threadID: fallbackThreadID,
            timestamp: nil,
            sourceReference: line.sourceReference,
            tokenUsage: nil,
            toolCall: nil,
            toolOutput: nil,
            parserErrorMessage: message,
            model: nil,
            reasoningEffort: nil,
            cwd: nil
        )
    }

    private func eventKind(
        rolloutType: String?,
        payloadType: String?,
        tokenUsage: ContextEfficiencyTokenUsage?
    ) -> CodexRolloutEventKind {
        if tokenUsage?.hasAnyTokenCount == true {
            return .tokenTelemetryObserved
        }
        if rolloutType == "session_meta" {
            return .sessionObserved
        }
        if rolloutType == "compacted" || payloadType?.localizedCaseInsensitiveContains("compact") == true {
            return .compactionObserved
        }
        if rolloutType == "response_item", payloadType == "function_call" {
            return .toolCallObserved
        }
        if rolloutType == "response_item",
           payloadType == "function_call_output" || payloadType == "custom_tool_call_output" {
            return .toolOutputObserved
        }
        if rolloutType == "event_msg", payloadType == "user_message" {
            return .userMessageObserved
        }
        if rolloutType == "event_msg", payloadType == "agent_message" {
            return .assistantMessageObserved
        }
        if rolloutType == nil {
            return .parserErrorObserved
        }
        return .unknownImported
    }

    private func threadID(from object: [String: Any], payload: [String: Any]?) -> String? {
        stringValue(
            for: [
                "thread_id",
                "threadID",
                "session_id",
                "sessionID",
                "conversation_id",
                "conversationID",
                "id",
            ],
            in: [object, payload]
        )
    }

    private func timestamp(from dictionary: [String: Any]) -> Date? {
        for key in ["timestamp", "created_at", "createdAt", "time", "ts"] {
            if let value = dictionary[key],
               let date = date(from: value) {
                return date
            }
        }
        return nil
    }

    private func date(from value: Any) -> Date? {
        if let date = value as? Date {
            return date
        }
        if let number = value as? NSNumber {
            return date(fromEpoch: number.doubleValue)
        }
        if let string = value as? String {
            if let number = Double(string) {
                return date(fromEpoch: number)
            }
            return iso8601Date(from: string)
        }
        return nil
    }

    private func iso8601Date(from string: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: string) {
            return date
        }
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractionalFormatter.date(from: string)
    }

    private func date(fromEpoch value: Double) -> Date {
        if value > 10_000_000_000 {
            return Date(timeIntervalSince1970: value / 1000)
        }
        return Date(timeIntervalSince1970: value)
    }

    private func stringValue(for keys: [String], in dictionaries: [[String: Any]?]) -> String? {
        for dictionary in dictionaries {
            guard let dictionary else { continue }
            for key in keys {
                if let value = dictionary[key] as? String,
                   !value.isEmpty {
                    return value
                }
            }
        }
        return nil
    }

    private func toolCall(from payload: [String: Any]?, payloadType: String?) -> CodexRolloutParsedToolCall? {
        guard payloadType == "function_call", let payload else {
            return nil
        }
        let summary = commandSummary.summary(from: payload["arguments"])
        return CodexRolloutParsedToolCall(
            callID: payload["call_id"] as? String,
            toolName: payload["name"] as? String,
            commandSummary: summary.command,
            argumentsByteCount: summary.byteCount
        )
    }

    private func toolOutput(from payload: [String: Any]?, payloadType: String?) -> CodexRolloutParsedToolOutput? {
        guard payloadType == "function_call_output" || payloadType == "custom_tool_call_output",
              let payload else {
            return nil
        }
        let output = outputSummary(from: payload["output"])
        return CodexRolloutParsedToolOutput(
            callID: payload["call_id"] as? String,
            outputByteCount: output.byteCount,
            estimatedOriginalTokens: estimatedOriginalTokenCount(in: output.markerText),
            rawOutputReferenceCount: rawOutputReferenceCount(in: output.markerText)
        )
    }

    private func outputSummary(from output: Any?) -> (markerText: String, byteCount: Int64) {
        if let output = output as? String {
            return (output, Int64(output.lengthOfBytes(using: .utf8)))
        }
        if let output,
           JSONSerialization.isValidJSONObject(output),
           let data = try? JSONSerialization.data(withJSONObject: output, options: [.sortedKeys]) {
            let markerText = String(data: data, encoding: .utf8) ?? ""
            return (markerText, Int64(data.count))
        }
        return ("", 0)
    }

    private func estimatedOriginalTokenCount(in output: String) -> Int64 {
        let marker = "Original token count:"
        guard let range = output.range(of: marker) else {
            return 0
        }
        let suffix = output[range.upperBound...]
        let digits = suffix.drop(while: { !$0.isNumber }).prefix(while: { $0.isNumber })
        return Int64(digits) ?? 0
    }

    private func rawOutputReferenceCount(in output: String) -> Int {
        let needle = "Raw output: bmux agent-token-output show"
        guard !needle.isEmpty else {
            return 0
        }
        var count = 0
        var searchRange = output.startIndex..<output.endIndex
        while let range = output.range(of: needle, options: [], range: searchRange) {
            count += 1
            searchRange = range.upperBound..<output.endIndex
        }
        return count
    }
}
