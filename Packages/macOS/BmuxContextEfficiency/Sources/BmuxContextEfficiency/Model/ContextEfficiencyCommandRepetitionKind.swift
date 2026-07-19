/// The repeated-command pattern detected from imported command facts.
public enum ContextEfficiencyCommandRepetitionKind: String, Codable, Equatable, Sendable {
    /// An exact normalized command repeated outside a more specific family.
    case command
    /// An exact normalized source-search command repeated.
    case sourceSearch = "source_search"
    /// An exact normalized file-reading command repeated.
    case fileReading = "file_reading"
}
