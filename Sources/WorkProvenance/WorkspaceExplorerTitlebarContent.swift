import BmuxAppKitSupportUI
import SwiftUI

/// Chooses the Explorer return chain or bmux's ordinary live workspace title.
struct WorkspaceExplorerTitlebarContent: View {
    let navigation: WorkspaceExplorerLiveNavigation?
    let selectedWorkspaceID: UUID?
    let directory: String?
    let title: String
    let reservedControlWidth: CGFloat
    let colorScheme: ColorScheme

    var body: some View {
        if let origin = navigation?.origin(for: selectedWorkspaceID) {
            WorkspaceExplorerLiveBreadcrumb(collectionTitle: origin.collectionTitle,
                hasCollection: origin.collectionTarget != nil, workspaceTitle: title,
                retainedSessionCount: navigation?.retainedSessionCount,
                leadingPadding: reservedControlWidth,
                onAllWorkspaces: { navigation?.returnToAllWorkspaces() },
                onCollection: { navigation?.returnToCollection() },
                onHistory: { navigation?.openHistory() })
        } else {
            WorkspaceTitlebarPresentation(directory: directory, title: title,
                buildNumber: AppBuildIdentityFormatter.buildNumber(),
                reservedControlWidth: reservedControlWidth,
                theme: MatteTheme(colorScheme: colorScheme))
        }
    }
}
