import SwiftUI

/// Workspace title and repository identity, with its trailing close action.
struct WorkspaceCardHeader<CloseIcon: View, TitleContent: View>: View {
    let repositoryName: String?
    let repositoryFont: Font
    let closeIcon: CloseIcon
    let closeButtonColor: Color
    let closeButtonSize: CGSize
    let canCloseWorkspace: Bool
    let showsCloseButton: Bool
    let closeButtonTooltip: String
    let onClose: () -> Void
    let titleContent: TitleContent

    init(
        repositoryName: String?,
        repositoryFont: Font,
        @ViewBuilder closeIcon: () -> CloseIcon,
        closeButtonColor: Color,
        closeButtonSize: CGSize,
        canCloseWorkspace: Bool,
        showsCloseButton: Bool,
        closeButtonTooltip: String,
        onClose: @escaping () -> Void,
        @ViewBuilder titleContent: () -> TitleContent
    ) {
        self.repositoryName = repositoryName
        self.repositoryFont = repositoryFont
        self.closeIcon = closeIcon()
        self.closeButtonColor = closeButtonColor
        self.closeButtonSize = closeButtonSize
        self.canCloseWorkspace = canCloseWorkspace
        self.showsCloseButton = showsCloseButton
        self.closeButtonTooltip = closeButtonTooltip
        self.onClose = onClose
        self.titleContent = titleContent()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                if let repositoryName {
                    WorkspaceRepositoryLabel(name: repositoryName, font: repositoryFont)
                }
                titleContent
            }

            if canCloseWorkspace {
                Button(action: onClose) {
                    closeIcon
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
