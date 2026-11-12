import Foundation

/// The caller's independently verified live identity or an explicit unavailable reason.
enum ProvenanceCallerResolution: Equatable {
    case available(workspaceID: String, surfaceID: String, providerSessionID: String)
    case unavailable(String)
}

extension BMUXCLI {
    /// Resolves a caller only when the live surface, provider thread, and hook state agree.
    func provenanceCallerIdentity(
        client: SocketClient,
        environment: [String: String]
    ) -> ProvenanceCallerResolution {
        func value(_ key: String) -> String? {
            guard let text = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                return nil
            }
            return text
        }
        guard let workspace = value("BMUX_WORKSPACE_ID"),
              let surface = value("BMUX_SURFACE_ID"),
              let provider = value("CODEX_THREAD_ID") ?? value("CODEX_SESSION_ID") else {
            return .unavailable("missing_caller")
        }
        if let alternate = value("CODEX_SESSION_ID"), alternate.caseInsensitiveCompare(provider) != .orderedSame {
            return .unavailable("conflicting_provider_identity")
        }
        let identified: [String: Any]
        do {
            identified = try client.sendV2(method: "system.identify", params: [
                "caller": ["workspace_id": workspace, "surface_id": surface]
            ])
        } catch {
            return .unavailable("app_linkage_unavailable")
        }
        guard let caller = identified["caller"] as? [String: Any],
              let actualWorkspace = caller["workspace_id"] as? String,
              let actualSurface = caller["surface_id"] as? String,
              let windowID = caller["window_id"] as? String,
              actualWorkspace.caseInsensitiveCompare(workspace) == .orderedSame,
              actualSurface.caseInsensitiveCompare(surface) == .orderedSame else {
            return .unavailable("caller_not_found")
        }
        let listed: [String: Any]
        do {
            listed = try client.sendV2(method: "workspace.list", params: ["window_id": windowID])
        } catch {
            return .unavailable("app_linkage_unavailable")
        }
        guard let workspaces = listed["workspaces"] as? [[String: Any]] else {
            return .unavailable("app_linkage_unavailable")
        }
        let matches = workspaces.filter {
            ($0["id"] as? String)?.caseInsensitiveCompare(actualWorkspace) == .orderedSame
        }
        guard matches.count <= 1 else { return .unavailable("ambiguous_caller") }
        guard let stable = matches.first?["stable_workspace_id"] as? String, !stable.isEmpty else {
            return .unavailable("caller_not_found")
        }
        let statePath = NSString(string: agentHookStatePath(sessionStoreSuffix: "codex", env: environment)).expandingTildeInPath
        let state: ClaudeHookSessionStoreFile
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: statePath))
            state = try JSONDecoder().decode(ClaudeHookSessionStoreFile.self, from: data)
        } catch {
            return .unavailable("hook_state_unavailable")
        }
        let activeMatches = state.activeSessionsBySurface.filter {
            $0.key.caseInsensitiveCompare(actualSurface) == .orderedSame
        }
        guard activeMatches.count <= 1 else { return .unavailable("ambiguous_caller") }
        guard let active = activeMatches.first?.value,
              active.sessionId.caseInsensitiveCompare(provider) == .orderedSame else {
            return .unavailable("caller_unlinked")
        }
        let records = state.sessions.values.filter { $0.sessionId.caseInsensitiveCompare(provider) == .orderedSame }
        guard records.count <= 1 else { return .unavailable("ambiguous_caller") }
        guard let record = records.first,
              record.workspaceId.caseInsensitiveCompare(actualWorkspace) == .orderedSame,
              record.surfaceId.caseInsensitiveCompare(actualSurface) == .orderedSame else {
            return .unavailable("caller_unlinked")
        }
        return .available(workspaceID: stable, surfaceID: actualSurface, providerSessionID: provider)
    }
}

extension BMUXCLI {
    func provenanceStableWorkspaceIDForRuntimeWorkspace(
        _ workspaceID: String,
        explicitSocketPath: String?,
        processEnv: [String: String],
        cliBundleIdentifier: String?
    ) -> String? {
        guard let socketPath = try? provenanceSocketPath(
            explicitSocketPath: explicitSocketPath, processEnv: processEnv, cliBundleIdentifier: cliBundleIdentifier
        ) else { return nil }
        let client = SocketClient(path: socketPath)
        defer { client.close() }
        guard (try? client.connect()) != nil,
              let payload = try? client.sendV2(method: "workspace.list") else {
            return nil
        }
        return provenanceStableWorkspaceID(fromWorkspaceListPayload: payload, matching: workspaceID)
    }

    private func provenanceStableWorkspaceID(
        fromWorkspaceListPayload payload: [String: Any],
        matching workspaceID: String
    ) -> String? {
        let requested = workspaceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requested.isEmpty,
              let workspaces = payload["workspaces"] as? [[String: Any]] else {
            return nil
        }
        for workspace in workspaces {
            let candidates = [
                workspace["id"] as? String,
                workspace["ref"] as? String,
                workspace["stable_workspace_id"] as? String,
            ]
            guard candidates.contains(where: { candidate in
                guard let candidate else { return false }
                return candidate.compare(requested, options: [.caseInsensitive]) == .orderedSame
            }) else {
                continue
            }
            let stableWorkspaceID = (workspace["stable_workspace_id"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return stableWorkspaceID?.isEmpty == false ? stableWorkspaceID : nil
        }
        return nil
    }

    func provenanceSocketPath(
        explicitSocketPath: String?, processEnv: [String: String], cliBundleIdentifier: String?
    ) throws -> String {
        let requestedPath: String
        let source: CLISocketPathSource
        if let explicitSocketPath {
            requestedPath = explicitSocketPath
            source = .explicitFlag
        } else if let envPath = try CLISocketEnvironment.socketPath(in: processEnv) {
            requestedPath = envPath
            source = CLISocketPathResolver.isImplicitDefaultPath(
                envPath, bundleIdentifier: cliBundleIdentifier, environment: processEnv
            ) ? .implicitDefault : .environment
        } else {
            requestedPath = CLISocketPathResolver.defaultSocketPath(bundleIdentifier: cliBundleIdentifier, environment: processEnv)
            source = .implicitDefault
        }
        return CLISocketPathResolver.resolve(requestedPath: requestedPath, source: source,
            environment: processEnv, bundleIdentifier: cliBundleIdentifier)
    }

}
