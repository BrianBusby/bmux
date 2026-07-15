import Foundation

/// Optimizes terminal command output for token-sensitive consumers.
///
/// This layer is intentionally independent of transcript parsing and storage.
/// A caller provides the command, raw output, and a stable message id; the layer
/// returns text suitable for model context plus a raw-output record that can be
/// stored locally for reversible expansion.
public struct TokenOptimizationLayer: Sendable {
    private let mode: TokenOptimizationMode
    private let optimizer: CommandOutputOptimizer
    private let referenceFactory: CommandOutputReferenceFactory

    /// Creates a token optimization layer with the native BMUX compressor.
    public init(mode: TokenOptimizationMode = .balanced) {
        self.mode = mode
        optimizer = CommandOutputOptimizer()
        referenceFactory = CommandOutputReferenceFactory()
    }

    /// Optimizes a terminal command output and creates a raw-output side-channel record.
    ///
    /// - Parameters:
    ///   - messageID: Stable id for the terminal result being optimized.
    ///   - command: Shell command that produced the output.
    ///   - rawOutput: Complete raw stdout/stderr body for the command.
    ///   - exitCode: Command exit code, when known.
    /// - Returns: Optimized output text, metadata, and the complete raw output record.
    public func optimizeTerminalOutput(
        messageID: String,
        command: String,
        rawOutput: String,
        exitCode: Int?
    ) -> TokenOptimizationResult {
        let candidate = optimizer.optimize(
            command: command,
            output: rawOutput,
            exitCode: exitCode
        )
        let optimization = effectiveOptimization(candidate, rawOutput: rawOutput)
        let rawOutputRef = referenceFactory.reference(
            messageID: messageID,
            command: command,
            rawOutput: rawOutput
        )
        let metadata = ChatTerminalOutputMetadata(
            kind: optimization.kind,
            rawOutputRef: rawOutputRef,
            rawByteCount: rawOutput.utf8.count,
            rawLineCount: lineCount(rawOutput),
            optimizedByteCount: optimization.text.utf8.count,
            omittedLineCount: optimization.omittedLineCount,
            wasOptimized: optimization.wasOptimized
        )
        let rawOutputRecord = ChatRawTerminalOutputRecord(
            messageID: messageID,
            command: command,
            rawOutput: rawOutput,
            metadata: metadata
        )
        return TokenOptimizationResult(
            kind: optimization.kind,
            output: optimization.text,
            metadata: metadata,
            rawOutputRecord: rawOutputRecord,
            wasOptimized: optimization.wasOptimized,
            omittedLineCount: optimization.omittedLineCount
        )
    }

    private func effectiveOptimization(
        _ optimization: CommandOutputOptimization,
        rawOutput: String
    ) -> CommandOutputOptimization {
        guard optimization.wasOptimized else { return optimization }
        switch mode {
        case .off:
            return rawOptimization(rawOutput)
        case .conservative:
            switch optimization.kind {
            case .tests, .packageInstall:
                return optimization
            case .build, .git, .typescript, .search, .generic:
                return rawOptimization(rawOutput, kind: optimization.kind)
            }
        case .balanced, .aggressive:
            return optimization
        }
    }

    private func rawOptimization(
        _ rawOutput: String,
        kind: CommandOutputKind = .generic
    ) -> CommandOutputOptimization {
        CommandOutputOptimization(
            kind: kind,
            text: rawOutput,
            wasOptimized: false,
            omittedLineCount: 0
        )
    }

    private func lineCount(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return text.split(separator: "\n", omittingEmptySubsequences: false).count
    }
}
