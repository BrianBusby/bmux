/// A git branch associated with workspace work context.
public struct WorkspaceWorkContextBranch: Equatable, Sendable {
    /// The branch name.
    public let name: String

    /// Whether the working tree is dirty.
    public let isDirty: Bool

    /// Where this branch value came from.
    public let source: WorkspaceWorkContextSource

    /// Whether the branch value may no longer match the active work.
    public let isStale: Bool

    /// Creates a branch context.
    /// - Parameters:
    ///   - name: The branch name.
    ///   - isDirty: Whether the working tree is dirty.
    ///   - source: Where this branch value came from.
    ///   - isStale: Whether the branch value may no longer match the active work.
    public init(
        name: String,
        isDirty: Bool,
        source: WorkspaceWorkContextSource,
        isStale: Bool = false
    ) {
        self.name = name
        self.isDirty = isDirty
        self.source = source
        self.isStale = isStale
    }
}
