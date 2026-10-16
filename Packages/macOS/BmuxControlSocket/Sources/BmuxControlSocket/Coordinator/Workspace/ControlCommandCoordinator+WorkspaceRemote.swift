internal import Foundation

/// Remote workspace mutation routing and authoritative result encoding.
extension ControlCommandCoordinator {
    private func workspaceRemoteResult(_ resolution: ControlWorkspaceRemoteResolution?) -> ControlCallResult {
        switch resolution ?? .missingWorkspaceID {
        case .missingWorkspaceID:
            return .err(code: "invalid_params", message: "Missing workspace_id", data: nil)
        case .notFound(let workspaceID):
            return .err(code: "not_found", message: "Workspace not found", data: .object([
                "workspace_id": .string(workspaceID.uuidString),
                "workspace_ref": ref(.workspace, workspaceID),
            ]))
        case .notConfigured(let workspaceID):
            return .err(code: "invalid_state", message: "Remote workspace is not configured", data: .object([
                "workspace_id": .string(workspaceID.uuidString),
                "workspace_ref": ref(.workspace, workspaceID),
            ]))
        case .reconnectFailed(let workspaceID, let surfaceID, let message):
            return .err(code: "invalid_state", message: message, data: .object([
                "workspace_id": .string(workspaceID.uuidString),
                "workspace_ref": ref(.workspace, workspaceID),
                "surface_id": .string(surfaceID.uuidString),
                "surface_ref": ref(.surface, surfaceID),
            ]))
        case .resolved(let windowID, let workspaceID, let remoteStatus):
            return .ok(.object([
                "window_id": orNull(windowID?.uuidString),
                "window_ref": ref(.window, windowID),
                "workspace_id": .string(workspaceID.uuidString),
                "workspace_ref": ref(.workspace, workspaceID),
                "remote": remoteStatus,
            ]))
        }
    }

    /// Resolves the explicit-or-fallback workspace id for the remote methods,
    /// reproducing the legacy `requestedWorkspaceId ?? selectedTabId` rule and
    /// its two `invalid_params` failures.
    private func remoteWorkspaceID(
        _ params: [String: JSONValue]
    ) -> (workspaceID: UUID?, error: ControlCallResult?) {
        let requested = uuid(params, "workspace_id")
        if hasNonNull(params, "workspace_id"), requested == nil {
            return (nil, .err(code: "invalid_params", message: "Missing or invalid workspace_id", data: nil))
        }
        let resolved = context?.controlResolveRemoteWorkspaceID(
            routing: routingSelectors(params),
            requestedWorkspaceID: requested
        )
        guard let resolved else {
            return (nil, .err(code: "invalid_params", message: "Missing workspace_id", data: nil))
        }
        return (resolved, nil)
    }

    /// `workspace.remote.configure` — configure a workspace's remote connection.
    func workspaceRemoteConfigure(_ params: [String: JSONValue]) -> ControlCallResult {
        let resolution = remoteWorkspaceID(params)
        if let error = resolution.error { return error }
        guard let workspaceID = resolution.workspaceID else {
            return .err(code: "invalid_params", message: "Missing workspace_id", data: nil)
        }
        return context?.controlConfigureWorkspaceRemote(params: params, workspaceID: workspaceID)
            ?? .err(code: "not_found", message: "Workspace not found", data: .object([
                "workspace_id": .string(workspaceID.uuidString),
                "workspace_ref": ref(.workspace, workspaceID),
            ]))
    }

    /// `workspace.remote.disconnect` — disconnect a workspace's remote.
    func workspaceRemoteDisconnect(_ params: [String: JSONValue]) -> ControlCallResult {
        let resolution = remoteWorkspaceID(params)
        if let error = resolution.error { return error }
        guard let workspaceID = resolution.workspaceID else {
            return .err(code: "invalid_params", message: "Missing workspace_id", data: nil)
        }
        let clearConfiguration = bool(params, "clear") ?? false
        return workspaceRemoteResult(context?.controlDisconnectWorkspaceRemote(
            workspaceID: workspaceID,
            clearConfiguration: clearConfiguration
        ))
    }

    /// `workspace.remote.reconnect` — reconnect a workspace's remote.
    func workspaceRemoteReconnect(_ params: [String: JSONValue]) -> ControlCallResult {
        let resolution = remoteWorkspaceID(params)
        if let error = resolution.error { return error }
        guard let workspaceID = resolution.workspaceID else {
            return .err(code: "invalid_params", message: "Missing workspace_id", data: nil)
        }
        let surfaceID = uuid(params, "surface_id")
        if hasNonNull(params, "surface_id"), surfaceID == nil {
            return .err(code: "invalid_params", message: "Missing or invalid surface_id", data: nil)
        }
        return workspaceRemoteResult(context?.controlReconnectWorkspaceRemote(
            workspaceID: workspaceID,
            surfaceID: surfaceID
        ))
    }

    /// `workspace.remote.foreground_auth_ready` — arm/continue a pending connect.
    func workspaceRemoteForegroundAuthReady(_ params: [String: JSONValue]) -> ControlCallResult {
        let resolution = remoteWorkspaceID(params)
        if let error = resolution.error { return error }
        guard let workspaceID = resolution.workspaceID else {
            return .err(code: "invalid_params", message: "Missing workspace_id", data: nil)
        }
        // Legacy `v2RawString(...)?.trimmingCharacters(...)`: trimmed, but an
        // empty string stays "" (NOT nil), so use the raw-trim, not the
        // empty-to-nil variant.
        let token = rawString(params, "foreground_auth_token")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return workspaceRemoteResult(context?.controlWorkspaceRemoteForegroundAuthReady(
            workspaceID: workspaceID,
            foregroundAuthToken: token
        ))
    }

    /// `workspace.remote.status` — read a workspace's remote status.
    func workspaceRemoteStatus(_ params: [String: JSONValue]) -> ControlCallResult {
        let resolution = remoteWorkspaceID(params)
        if let error = resolution.error { return error }
        guard let workspaceID = resolution.workspaceID else {
            return .err(code: "invalid_params", message: "Missing workspace_id", data: nil)
        }
        return workspaceRemoteResult(context?.controlWorkspaceRemoteStatus(workspaceID: workspaceID))
    }
}
