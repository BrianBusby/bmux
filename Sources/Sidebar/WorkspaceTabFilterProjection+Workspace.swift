import Foundation

extension WorkspaceTabFilterProjection {
    @MainActor
    func items(for tabs: [Workspace]) -> [WorkspaceFilterItem] {
        tabs.map { tab in
            let directory = tab.currentDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
            let repo = directory.isEmpty ? nil : URL(fileURLWithPath: directory).lastPathComponent
            let projectPath = tab.extensionSidebarProjectRootPath?.trimmingCharacters(in: .whitespacesAndNewlines)
            let project = projectPath.flatMap { path in
                path.isEmpty ? nil : URL(fileURLWithPath: path).lastPathComponent
            }
            let pullRequest = tab.pullRequest
            let status: WorkspaceStatusKind
            if tab.isRemoteWorkspace, tab.remoteConnectionState == .disconnected {
                status = .error
            } else if tab.isRemoteWorkspace,
                      tab.remoteConnectionState == .connecting || tab.remoteConnectionState == .reconnecting {
                status = .waiting
            } else {
                status = .active
            }
            let ticket = tab.sidebarMetadata.workContext.ticket?.key
            let links = [
                pullRequest.map { "\($0.label) \($0.number)" },
                ticket
            ].compactMap { $0 }
            return WorkspaceFilterItem(
                id: tab.id,
                title: tab.title,
                status: status,
                owner: pullRequest?.ownerLogin,
                repo: repo,
                project: project,
                branch: tab.gitBranch?.branch,
                links: links
            )
        }
    }
}
