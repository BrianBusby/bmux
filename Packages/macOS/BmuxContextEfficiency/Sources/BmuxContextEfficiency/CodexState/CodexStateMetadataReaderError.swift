/// Errors produced while reading Codex state metadata.
public enum CodexStateMetadataReaderError: Error, Equatable, Sendable {
    /// No Codex state SQLite database exists at the resolved location.
    case databaseNotFound(String)
    /// The Codex state schema does not contain the expected compact metadata.
    case unsupportedSchema(String)
    /// SQLite returned an error message.
    case sqlite(String)
}
