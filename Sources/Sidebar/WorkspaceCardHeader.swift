import SwiftUI

/// Workspace title and repository identity, with its trailing close action.
struct WorkspaceCardHeader<CloseIcon: View, TitleContent: View>: View {
    let repositoryName: String?
    let repositoryFont: Font
    @ViewBuilder let closeIcon: () -> CloseIcon
    let closeButtonColor: Color
    let closeButtonSize: CGSize
    let canCloseWorkspace: Bool
    let showsCloseButton: Bool
    let closeButtonTooltip: String
    let onClose: () -> Void
    @ViewBuilder let titleContent: () -> TitleContent

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                if let repositoryName {
                    WorkspaceRepositoryLabel(name: repositoryName, font: repositoryFont)
                }
                titleContent()
            }

            if canCloseWorkspace {
                Button(action: onClose) {
                    closeIcon()
                        .foregroundStyle(closeButtonColor)
                        .frame(width: closeButtonSize.width, height: closeButtonSize.height)
                }
                .buttonStyle(.plain)
                .safeHelp(closeButtonTooltip)
                .opacity(showsCloseButton ? 1 : 0)
                .allowsHitTesting(showsCloseButton)
                .accessibilityHidden(!showsCloseButton)
            }
        }
    }
}
