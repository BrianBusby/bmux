import Foundation

/// Identifies where an imported fact came from in a source evidence file.
public struct ContextEfficiencySourceReference: Codable, Equatable, Hashable, Sendable {
    /// Absolute or caller-supplied path to the source evidence file.
    public var sourcePath: String
    /// Byte offset for the beginning of the source line.
    public var byteOffset: Int64
    /// One-based source line number.
    public var lineNumber: Int
    /// Parser version that produced this reference.
    public var parserVersion: Int

    /// Creates a source reference for an imported event.
    ///
    /// - Parameters:
    ///   - sourcePath: Absolute or caller-supplied path to the source evidence file.
    ///   - byteOffset: Byte offset for the beginning of the source line.
    ///   - lineNumber: One-based source line number.
    ///   - parserVersion: Parser version that produced this reference.
    public init(sourcePath: String, byteOffset: Int64, lineNumber: Int, parserVersion: Int) {
        self.sourcePath = sourcePath
        self.byteOffset = byteOffset
        self.lineNumber = lineNumber
        self.parserVersion = parserVersion
    }
}
