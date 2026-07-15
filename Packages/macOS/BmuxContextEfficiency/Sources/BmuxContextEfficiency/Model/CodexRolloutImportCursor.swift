public import Foundation

/// Incremental import position for one Codex rollout JSONL source.
public struct CodexRolloutImportCursor: Codable, Equatable, Sendable {
    /// Source rollout path.
    public var sourcePath: String
    /// Next byte offset to read from.
    public var byteOffset: Int64
    /// Last completed one-based source line number.
    public var lineNumber: Int
    /// Most recent source file size observed by the importer.
    public var fileSize: Int64
    /// Parser version used for the cursor.
    public var parserVersion: Int
    /// Time the cursor was updated.
    public var updatedAt: Date

    /// Creates an import cursor.
    public init(
        sourcePath: String,
        byteOffset: Int64,
        lineNumber: Int,
        fileSize: Int64,
        parserVersion: Int,
        updatedAt: Date
    ) {
        self.sourcePath = sourcePath
        self.byteOffset = byteOffset
        self.lineNumber = lineNumber
        self.fileSize = fileSize
        self.parserVersion = parserVersion
        self.updatedAt = updatedAt
    }
}
