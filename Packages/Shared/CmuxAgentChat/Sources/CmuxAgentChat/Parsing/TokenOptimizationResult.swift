import Foundation

/// The optimized representation of one terminal command output.
public struct TokenOptimizationResult: Sendable, Equatable {
    /// The command/output category selected by the optimizer.
    public let kind: CommandOutputKind

    /// The text that should be forwarded to a token-sensitive consumer.
    public let output: String

    /// Metadata describing the raw and optimized output relationship.
    public let metadata: ChatTerminalOutputMetadata

    /// The complete raw output record that callers may persist locally.
    public let rawOutputRecord: ChatRawTerminalOutputRecord

    /// Whether ``output`` differs from the raw command output.
    public let wasOptimized: Bool

    /// Number of raw output lines omitted from ``output``.
    public let omittedLineCount: Int

    /// Creates an optimized terminal command output result.
    ///
    /// - Parameters:
    ///   - kind: Command/output category selected by the optimizer.
    ///   - output: Text that should be forwarded to a token-sensitive consumer.
    ///   - metadata: Metadata describing the raw and optimized output relationship.
    ///   - rawOutputRecord: Complete raw output record that callers may persist locally.
    ///   - wasOptimized: Whether `output` differs from the raw command output.
    ///   - omittedLineCount: Number of raw output lines omitted from `output`.
    public init(
        kind: CommandOutputKind,
        output: String,
        metadata: ChatTerminalOutputMetadata,
        rawOutputRecord: ChatRawTerminalOutputRecord,
        wasOptimized: Bool,
        omittedLineCount: Int
    ) {
        self.kind = kind
        self.output = output
        self.metadata = metadata
        self.rawOutputRecord = rawOutputRecord
        self.wasOptimized = wasOptimized
        self.omittedLineCount = omittedLineCount
    }
}
