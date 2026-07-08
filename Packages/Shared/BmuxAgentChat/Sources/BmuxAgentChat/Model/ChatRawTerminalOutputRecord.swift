import Foundation

/// Complete raw terminal output captured during transcript parsing.
public struct ChatRawTerminalOutputRecord: Sendable, Equatable, Codable {
    /// The chat message id of the terminal capture this record belongs to.
    public let messageID: String

    /// The command line as submitted to the shell.
    public let command: String

    /// Complete raw command output body, without transcript transport headers.
    public let rawOutput: String

    /// Metadata attached to the rendered terminal capture.
    public let metadata: ChatTerminalOutputMetadata

    /// Creates a raw terminal output record.
    ///
    /// - Parameters:
    ///   - messageID: Chat message id of the terminal capture.
    ///   - command: Command line as submitted to the shell.
    ///   - rawOutput: Complete raw command output body.
    ///   - metadata: Metadata attached to the rendered terminal capture.
    public init(
        messageID: String,
        command: String,
        rawOutput: String,
        metadata: ChatTerminalOutputMetadata
    ) {
        self.messageID = messageID
        self.command = command
        self.rawOutput = rawOutput
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case command
        case rawOutput = "raw_output"
        case metadata
    }
}
