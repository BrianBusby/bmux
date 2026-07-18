/// Normalized family for a command observed in imported agent telemetry.
public enum ContextEfficiencyCommandCategory: String, Codable, Equatable, Sendable {
    /// Source search commands.
    case sourceSearch = "source_search"
    /// File-reading commands.
    case fileReading = "file_reading"
    /// Git status and working-tree overview commands.
    case gitStatus = "git_status"
    /// Git diff commands.
    case gitDiff = "git_diff"
    /// Git history and object inspection commands.
    case gitLog = "git_log"
    /// Build commands.
    case buildRuns = "builds"
    /// Commands that run validation suites.
    case validationRuns = "tests"
    /// Commands that check static types.
    case checkTypes = "type_checking"
    /// Linting or formatting-check commands.
    case qualityChecks = "linting"
    /// Dependency installation commands.
    case dependencyInstall = "package_installation"
    /// Code generation commands.
    case codeGeneration = "code_generation"
    /// Server log inspection commands.
    case serverLogs = "server_logs"
    /// Directory listing and navigation inspection commands.
    case directoryListing = "directory_listing"
    /// Process inspection commands.
    case processMonitoring = "process_monitoring"
    /// Commands that do not match a known family.
    case arbitraryUnknown = "arbitrary_unknown"
}
