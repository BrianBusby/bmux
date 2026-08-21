import Foundation

/// Extracts real user prompts from an existing Codex transcript JSONL file.
public struct CodexTranscriptPromptBackfill: Sendable {
    /// Maximum complete transcript lines parsed from the file tail.
    public let maxLines: Int

    private let tokenOptimizationMode: TokenOptimizationMode

    /// Creates a prompt backfill extractor.
    ///
    /// - Parameters:
    ///   - maxLines: Maximum complete transcript lines parsed from the file tail.
    ///   - tokenOptimizationMode: Output optimization mode passed through to the transcript parser.
    public init(maxLines: Int = 10_000, tokenOptimizationMode: TokenOptimizationMode = .balanced) {
        self.maxLines = maxLines
        self.tokenOptimizationMode = tokenOptimizationMode
    }

    /// Reads a Codex transcript file and returns user prompt messages.
    ///
    /// - Parameter path: Absolute path to a Codex rollout JSONL transcript.
    /// - Returns: User-authored prose messages parsed from the bounded transcript tail.
    public func userPromptMessages(path: String) -> [ChatMessage] {
        guard let parsed = completeTailLines(path: path) else { return [] }
        return userPromptMessages(lines: parsed.lines, startingSeq: parsed.startingSeq)
    }

    /// Returns user prompt messages from already-loaded Codex transcript lines.
    ///
    /// - Parameters:
    ///   - lines: Complete JSONL lines from a Codex transcript.
    ///   - startingSeq: Absolute line index of `lines.first`.
    /// - Returns: User-authored prose messages parsed from the supplied lines.
    public func userPromptMessages(lines: [String], startingSeq: Int = 0) -> [ChatMessage] {
        let result = CodexTranscriptParser(tokenOptimizationMode: tokenOptimizationMode)
            .parse(lines: lines, startingSeq: startingSeq)
        return result.messages.compactMap(Self.userPromptMessage)
    }

    private func completeTailLines(path: String) -> (lines: [String], startingSeq: Int)? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe),
              !data.isEmpty else {
            return nil
        }
        var starts = [0]
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            for index in 0..<raw.count where raw[index] == 0x0A {
                starts.append(index + 1)
            }
        }
        let completeLineCount = starts.count - 1
        guard completeLineCount > 0 else { return nil }
        let firstLine = max(0, completeLineCount - maxLines)
        var lines: [String] = []
        lines.reserveCapacity(completeLineCount - firstLine)
        for lineIndex in firstLine..<completeLineCount {
            let range = starts[lineIndex]..<(starts[lineIndex + 1] - 1)
            lines.append(String(decoding: data[range], as: UTF8.self))
        }
        return (lines, firstLine)
    }

    private static func userPromptMessage(_ message: ChatMessage) -> ChatMessage? {
        guard message.role == .user,
              case .prose(let prose) = message.kind,
              !prose.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return message
    }
}
