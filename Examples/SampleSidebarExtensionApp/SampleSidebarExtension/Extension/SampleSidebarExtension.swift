import BmuxExtensionKit
import SwiftUI

@main
final class SampleSidebarExtension: @MainActor BmuxSidebarExtension {
    static let manifest = BmuxExtensionManifest(
        id: "co.manaflow.BMUXExtKitSampleSidebarApp.Extension",
        displayName: String(localized: "sampleSidebar.manifest.displayName", defaultValue: "BMUX Sample Sidebar Extension"),
        readScopes: [
            .workspaceList,
            .workspaceMetadata,
            .surfaceMetadata,
            .notifications,
            .networkPorts,
            .pullRequests,
        ],
        actionScopes: [
            .createSurface,
            .selectWorkspace,
            .selectSurface,
            .navigateWorkspace,
            .navigateSurface,
        ]
    )

    private let model = SidebarConnectionModel()

    required init() {}

    var body: some View {
        SampleSidebarView(model: model)
    }

    func update(context: BmuxSidebarContext) {
        model.update(context: context)
    }

    func connectionStatusDidChange(_ status: BmuxSidebarConnectionStatus) {
        model.connectionStatusDidChange(status)
    }
}
