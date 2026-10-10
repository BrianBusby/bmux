import Foundation

extension WorkspaceTabFilterProjection {
    @MainActor
    func items(for tabs: [Workspace], cards: [WorkspaceReferenceCardSnapshot] = []) -> [WorkspaceFilterItem] {
        let cardsByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        return tabs.map { tab in
            let card = cardsByID[tab.id]
            let directory = tab.currentDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
            let repo = directory.isEmpty ? nil : URL(fileURLWithPath: directory).lastPathComponent
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
            let links = [
                card?.title,
                card?.pullRequestText ?? pullRequest.map { "\($0.label) \($0.number)" },
                card?.ticketID
            ].compactMap { $0 }
            return WorkspaceFilterItem(
                id: tab.id,
                title: tab.title,
                status: status,
                owner: card?.pullRequestOwnerLogin ?? pullRequest?.ownerLogin,
                repo: repo,
                project: card?.projectFilterTitle,
                branch: card?.branch,
                links: links
            )
        }
    }
}
