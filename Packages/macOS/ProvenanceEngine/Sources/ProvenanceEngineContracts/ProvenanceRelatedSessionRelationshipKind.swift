import Foundation

/// Deterministic relationship reason kinds supported by the related-session read model.
public enum ProvenanceRelatedSessionRelationshipKind: String, Codable, Equatable, Sendable, CaseIterable {
    /// The sessions have an accepted fact for the same repository.
    case sameRepository = "same_repository"

    /// The sessions have an accepted fact for the same worktree.
    case sameWorktree = "same_worktree"

    /// The sessions have an accepted fact for the same branch within a shared repository.
    case sameBranch = "same_branch"

    /// The related session is an accepted session-tree ancestor of the target.
    case sessionTreeAncestor = "session_tree_ancestor"

    /// The related session is an accepted session-tree descendant of the target.
    case sessionTreeDescendant = "session_tree_descendant"

    /// The sessions share an accepted session-tree parent.
    case sessionTreeSibling = "session_tree_sibling"

    /// The sessions share an explicitly observed provider thread identity.
    case sharedProviderThread = "shared_provider_thread"

    /// The sessions share an explicitly observed provider/runtime identity.
    case sharedExternalIdentity = "shared_external_identity"

    /// The sessions have accepted outcome facts for the same changed artifact.
    case sharedChangedArtifact = "shared_changed_artifact"
}
