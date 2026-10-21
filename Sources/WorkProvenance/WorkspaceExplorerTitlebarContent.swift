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
                workspaceTitle: title, leadingPadding: reservedControlWidth,
                onBack: { navigation?.returnToExplorer() })
        } else {
            WorkspaceTitlebarPresentation(directory: directory, title: title,
                buildNumber: AppBuildIdentityFormatter.buildNumber(),
                reservedControlWidth: reservedControlWidth,
                theme: MatteTheme(colorScheme: colorScheme))
        }
    }
}
