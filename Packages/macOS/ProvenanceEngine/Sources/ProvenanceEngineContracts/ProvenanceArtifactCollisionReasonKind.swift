/// Factual relationship kind used by artifact-collision awareness.
public enum ProvenanceArtifactCollisionReasonKind: String, Codable, Equatable, Sendable, CaseIterable {
    /// Two or more sessions changed the same normalized repository-relative path.
    case exactPathOverlap = "exact_path_overlap"

    /// Candidate participants share at least one accepted repository identity.
    case sharedRepository = "shared_repository"

    /// Candidate participants share an accepted worktree identity.
    case sameWorktree = "same_worktree"

    /// Candidate participants have distinct accepted worktree identities.
    case differentWorktrees = "different_worktrees"

    /// Candidate participants share an accepted branch name inside a shared repository boundary.
    case sameBranch = "same_branch"

    /// Candidate participants have distinct accepted branch names.
    case differentBranches = "different_branches"

    /// Candidate participants share an accepted HEAD boundary.
    case sameHead = "same_head"

    /// Candidate participants have distinct accepted HEAD boundaries.
    case divergentHead = "divergent_head"

    /// Session or artifact observation ranges overlap in time.
    case temporallyOverlappingEdits = "temporally_overlapping_edits"

    /// The overlap is derived from completed sessions without current edit activity.
    case historicalOverlap = "historical_overlap"

    /// The overlap is older than the request's stale boundary.
    case staleOverlap = "stale_overlap"

    /// Required factual evidence is missing or partial.
    case incompleteEvidence = "incomplete_evidence"

    /// Stable rename identity is not supported without accepted rename evidence.
    case unsupportedRenameIdentity = "unsupported_rename_identity"
}
