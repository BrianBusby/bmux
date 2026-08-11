import BmuxSwiftRender
import BmuxSidebarProviderKit
import Foundation

extension Workspace {
    /// Pull-request values projected for the custom-sidebar interpreter
    /// context (`workspaces[i].pr` / `workspaces[i].prs`). Reads the per-panel
    /// pull-request state in sidebar display order rather than the
    /// focused-panel `pullRequest` mirror: the mirror only refreshes while its
    /// panel is focused, so it is routinely nil for background workspaces that
    /// do have a known open PR.
    func customSidebarPullRequestValues(
        provenanceDisplaySnapshot: WorkspaceDisplayCurrentStateSnapshot? = nil
    ) -> [SwiftValue] {
        if let provenancePullRequest = provenanceDisplaySnapshot?.pullRequest {
            return [Self.customSidebarPullRequestValue(provenancePullRequest)]
        }
        return sidebarPullRequestsInDisplayOrder().map { pullRequest in
            var fields: [String: SwiftValue] = [
                "number": .int(pullRequest.number),
                "label": .string(pullRequest.label),
                "url": .string(pullRequest.url.absoluteString),
                "status": .string(pullRequest.status.rawValue),
                "stale": .bool(pullRequest.isStale),
            ]
            if let ownerLogin = pullRequest.ownerLogin { fields["owner"] = .string(ownerLogin) }
            if let ownerURL = pullRequest.ownerURL { fields["owner_url"] = .string(ownerURL.absoluteString) }
            if let branch = pullRequest.branch { fields["branch"] = .string(branch) }
            return .object(fields)
        }
    }

    private static func customSidebarPullRequestValue(
        _ pullRequest: WorkspaceDisplayCurrentStatePullRequestSnapshot
    ) -> SwiftValue {
        let label = String(localized: "sidebar.pullRequest.label", defaultValue: "PR")
        var fields: [String: SwiftValue] = [
            "number": .int(pullRequest.number),
            "label": .string(label),
            "url": .string(pullRequest.url?.absoluteString ?? ""),
            "stale": .bool(pullRequest.isStale),
        ]
        if let status = pullRequest.status { fields["status"] = .string(status) }
        if let ownerLogin = pullRequest.ownerLogin { fields["owner"] = .string(ownerLogin) }
        if let ownerURL = pullRequest.ownerURL { fields["owner_url"] = .string(ownerURL.absoluteString) }
        if let branch = pullRequest.branch { fields["branch"] = .string(branch) }
        return .object(fields)
    }

    func sidebarProviderPullRequests(
        provenanceDisplaySnapshot: WorkspaceDisplayCurrentStateSnapshot? = nil
    ) -> [BmuxSidebarProviderPullRequest] {
        if let pullRequest = provenanceDisplaySnapshot?.pullRequest {
            return [BmuxSidebarProviderPullRequest(
                number: pullRequest.number,
                label: String(localized: "sidebar.pullRequest.label", defaultValue: "PR"),
                url: pullRequest.url?.absoluteString ?? "",
                status: pullRequest.status ?? "open",
                ownerLogin: pullRequest.ownerLogin,
                ownerURL: pullRequest.ownerURL?.absoluteString,
                branch: pullRequest.branch,
                isStale: pullRequest.isStale
            )]
        }
        return sidebarPullRequestsInDisplayOrder().map {
            BmuxSidebarProviderPullRequest(
                number: $0.number,
                label: $0.label,
                url: $0.url.absoluteString,
                status: $0.status.rawValue,
                ownerLogin: $0.ownerLogin,
                ownerURL: $0.ownerURL?.absoluteString,
                branch: $0.branch,
                isStale: $0.isStale
            )
        }
    }
}
