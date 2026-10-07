public import Foundation

/// Value object deciding which workspace portal-rendering transitions need to run.
///
/// `WorkspaceMountPlan` decides which workspaces should stay mounted. This type
/// combines that mounted set with the visibility of its content, then compares
/// the result with the last applied state. Chat and Session can retain mounted
/// workspaces without allowing their terminal or browser portals to render.
public struct WorkspacePortalRenderingPlan: Equatable {
    private let previousStatesByWorkspaceId: [UUID: Bool]
    private let mountedWorkspaceIds: Set<UUID>
    private let orderedWorkspaceIds: [UUID]

    /// Creates a portal-rendering reconciliation plan.
    ///
    /// - Parameters:
    ///   - previousStatesByWorkspaceId: The last portal-rendering state applied by
    ///     the caller, keyed by workspace id.
    ///   - mountedWorkspaceIds: Workspaces eligible for portal rendering when content is visible.
    ///   - orderedWorkspaceIds: Existing workspaces in stable application order.
    ///   - contentVisible: Whether the containing terminal content is displayed.
    ///     False disables every portal without changing workspace mount lifetime.
    public init(
        previousStatesByWorkspaceId: [UUID: Bool],
        mountedWorkspaceIds: Set<UUID>,
        orderedWorkspaceIds: [UUID],
        contentVisible: Bool = true
    ) {
        self.previousStatesByWorkspaceId = previousStatesByWorkspaceId
        self.mountedWorkspaceIds = contentVisible ? mountedWorkspaceIds : []
        self.orderedWorkspaceIds = orderedWorkspaceIds
    }

    /// The workspace portal-rendering transitions that should be applied.
    public var changes: [WorkspacePortalRenderingChange] {
        var seenWorkspaceIds = Set<UUID>()
        return orderedWorkspaceIds.compactMap { workspaceId -> WorkspacePortalRenderingChange? in
            guard seenWorkspaceIds.insert(workspaceId).inserted else {
                return nil
            }
            let desiredState = mountedWorkspaceIds.contains(workspaceId)
            guard previousStatesByWorkspaceId[workspaceId] != desiredState else {
                return nil
            }
            return WorkspacePortalRenderingChange(workspaceId: workspaceId, isEnabled: desiredState)
        }
    }

    /// The state snapshot to persist after applying ``changes``.
    public var nextStatesByWorkspaceId: [UUID: Bool] {
        Dictionary(orderedWorkspaceIds.map { workspaceId in
            (workspaceId, mountedWorkspaceIds.contains(workspaceId))
        }, uniquingKeysWith: { first, _ in first })
    }

    /// Applies this plan to the caller's previous state snapshot.
    ///
    /// - Parameters:
    ///   - previousStatesByWorkspaceId: The caller's state snapshot. This value is
    ///     replaced with ``nextStatesByWorkspaceId``.
    /// - Returns: The portal-rendering transitions that should be applied.
    public func applying(
        to previousStatesByWorkspaceId: inout [UUID: Bool]
    ) -> [WorkspacePortalRenderingChange] {
        previousStatesByWorkspaceId = nextStatesByWorkspaceId
        return changes
    }
}
