import Foundation

/// Metadata describing how a terminal command output was optimized.
public struct ChatTerminalOutputMetadata: Sendable, Equatable, Codable {
    /// The command/output category used by the optimizer.
    public let kind: CommandOutputKind

    /// A local-only handle that can be resolved to the complete raw output.
    public let rawOutputRef: String?

    /// The UTF-8 byte count of the complete raw command output body.
    public let rawByteCount: Int

    /// The line count of the complete raw command output body.
    public let rawLineCount: Int

    /// The UTF-8 byte count of the optimized output stored on the capture.
    public let optimizedByteCount: Int?

    /// Number of raw output lines omitted from the optimized output.
    public let omittedLineCount: Int

    /// Whether the capture output differs from the raw output body.
    public let wasOptimized: Bool

    /// Creates terminal output optimization metadata.
    ///
    /// - Parameters:
    ///   - kind: The command/output category used by the optimizer.
    ///   - rawOutputRef: Local-only handle for resolving the complete raw output.
    ///   - rawByteCount: UTF-8 byte count of the raw command output body.
    ///   - rawLineCount: Line count of the raw command output body.
    ///   - optimizedByteCount: UTF-8 byte count of the optimized output.
    ///   - omittedLineCount: Number of raw lines omitted from the optimized output.
    ///   - wasOptimized: Whether the capture output differs from the raw output body.
    public init(
        kind: CommandOutputKind,
        rawOutputRef: String?,
        rawByteCount: Int,
        rawLineCount: Int,
        optimizedByteCount: Int?,
        omittedLineCount: Int,
        wasOptimized: Bool
    ) {
        self.kind = kind
        self.rawOutputRef = rawOutputRef
        self.rawByteCount = rawByteCount
        self.rawLineCount = rawLineCount
        self.optimizedByteCount = optimizedByteCount
        self.omittedLineCount = omittedLineCount
        self.wasOptimized = wasOptimized
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case rawOutputRef = "raw_output_ref"
        case rawByteCount = "raw_byte_count"
        case rawLineCount = "raw_line_count"
        case optimizedByteCount = "optimized_byte_count"
        case omittedLineCount = "omitted_line_count"
        case wasOptimized = "was_optimized"
    }
}
