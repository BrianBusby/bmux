import BmuxSidebarProviderKit
import Foundation

public enum SidebarExamples {
    public static let providers: [any BmuxSidebarProvider] = [
        ProjectWorktreeSidebar(),
        AttentionQueueSidebar(),
        DevServerSidebar(),
        LastPromptSidebar(),
        SuperCompactSidebar(),
        BrowserStackSidebar(onAsyncStateLoaded: {
            BrowserStackSidebar.postStateDidLoadNotification()
        }),
    ]
}

struct ExampleSidebarSection {
    var id: String
    var title: BmuxSidebarProviderLocalizedText
    var systemImageName: String
    var projectRootPath: String?
    var workspaces: [BmuxSidebarProviderWorkspace]

    func render(
        rowTitle: (BmuxSidebarProviderWorkspace) -> String = { $0.title },
        accessory: BmuxSidebarProviderRowAccessory? = .inspector,
        subtitle: (BmuxSidebarProviderWorkspace) -> BmuxSidebarProviderText? = { _ in nil },
        trailingText: (BmuxSidebarProviderWorkspace) -> BmuxSidebarProviderText? = { _ in nil },
        leadingIcon: (BmuxSidebarProviderWorkspace) -> BmuxSidebarProviderIcon? = { _ in nil }
    ) -> BmuxSidebarProviderSection {
        BmuxSidebarProviderSection(
            id: id,
            treeSection: BmuxSidebarProviderTreeSection(
                id: id,
                title: title.defaultValue,
                titleText: title,
                subtitle: nil,
                systemImageName: systemImageName,
                projectRootPath: projectRootPath,
                workspaceIds: workspaces.map(\.id)
            ),
            rows: workspaces.map { workspace in
                BmuxSidebarProviderRow(
                    id: workspace.id,
                    title: rowTitle(workspace),
                    workspaceId: workspace.id,
                    accessory: accessory,
                    subtitle: subtitle(workspace),
                    trailingText: trailingText(workspace),
                    leadingIcon: leadingIcon(workspace)
                )
            }
        )
    }
}

func localized(_ key: String, _ defaultValue: String) -> BmuxSidebarProviderLocalizedText {
    BmuxSidebarProviderLocalizedText(key: key, defaultValue: defaultValue)
}

func renderModel(
    providerId: String,
    snapshot: BmuxSidebarProviderSnapshot,
    sections: [BmuxSidebarProviderSection],
    presentation: BmuxSidebarProviderPresentation = .tree
) -> BmuxSidebarProviderRenderModel {
    BmuxSidebarProviderRenderModel(
        providerId: providerId,
        snapshotSequence: snapshot.sequence,
        sections: presentation == .browserStack ? sections : sections.filter { !$0.rows.isEmpty },
        presentation: presentation
    )
}

func trimmed(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}

func projectRoot(for workspace: BmuxSidebarProviderWorkspace) -> String? {
    trimmed(workspace.projectRootPath)
}

func displayName(for path: String) -> String {
    let url = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    let name = url.lastPathComponent
    return name.isEmpty ? path : name
}
