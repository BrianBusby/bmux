import SwiftUI

/// Workspace repository and ticket identity, with its trailing activity or close action.
struct WorkspaceCardHeader<TicketIcon: View, CloseIcon: View, TitleContent: View>: View {
    let repositoryName: String?
    let repositoryFont: Font
    let ticketID: String?
    let ticketFont: Font
    let ticketIcon: TicketIcon
    let ticketColor: Color
    let ticketBorderColor: Color
    let onOpenTicket: (() -> Void)?
    let closeIcon: CloseIcon
    let closeButtonColor: Color
    let closeButtonSize: CGSize
    let hasActiveAIWork: Bool
    let canCloseWorkspace: Bool
    let showsCloseButton: Bool
    let closeButtonTooltip: String
    let onClose: () -> Void
    let titleContent: TitleContent

    init(
        repositoryName: String?,
        repositoryFont: Font,
        ticketID: String?,
        ticketFont: Font,
        @ViewBuilder ticketIcon: () -> TicketIcon,
        ticketColor: Color,
        ticketBorderColor: Color,
        onOpenTicket: (() -> Void)?,
        @ViewBuilder closeIcon: () -> CloseIcon,
        closeButtonColor: Color,
        closeButtonSize: CGSize,
        hasActiveAIWork: Bool,
        canCloseWorkspace: Bool,
        showsCloseButton: Bool,
        closeButtonTooltip: String,
        onClose: @escaping () -> Void,
        @ViewBuilder titleContent: () -> TitleContent
    ) {
        self.repositoryName = repositoryName
        self.repositoryFont = repositoryFont
        self.ticketID = ticketID
        self.ticketFont = ticketFont
        self.ticketIcon = ticketIcon()
        self.ticketColor = ticketColor
        self.ticketBorderColor = ticketBorderColor
        self.onOpenTicket = onOpenTicket
        self.closeIcon = closeIcon()
        self.closeButtonColor = closeButtonColor
        self.closeButtonSize = closeButtonSize
        self.hasActiveAIWork = hasActiveAIWork
        self.canCloseWorkspace = canCloseWorkspace
        self.showsCloseButton = showsCloseButton
        self.closeButtonTooltip = closeButtonTooltip
        self.onClose = onClose
        self.titleContent = titleContent()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                if repositoryName != nil || ticketID != nil {
                    HStack(spacing: 10) {
                        if let repositoryName {
                            WorkspaceRepositoryLabel(name: repositoryName, font: repositoryFont)
                        }
                        if let ticketID {
                            ticketBadge(ticketID)
                                .layoutPriority(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                titleContent
            }

            if hasActiveAIWork {
                let label = String(localized: "sidebar.aiBusy.tooltip", defaultValue: "AI is running or needs input")
                TronLoadingIndicator(size: 18, color: closeButtonColor, lineWidth: 1.5)
                    .frame(width: closeButtonSize.width, height: closeButtonSize.height)
                    .safeHelp(label)
                    .accessibilityLabel(label)
                    .allowsHitTesting(false)
            } else if canCloseWorkspace {
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

    @ViewBuilder
    private func ticketBadge(_ ticketID: String) -> some View {
        let label = HStack(spacing: 6) {
            ticketIcon
            Text(ticketID)
                .font(ticketFont)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(ticketColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(ticketBorderColor, lineWidth: 1)
        }

        if let onOpenTicket {
            Button(action: onOpenTicket) { label }
                .buttonStyle(.plain)
                .safeHelp(String(
                    format: String(localized: "sidebar.ticket.openTooltip", defaultValue: "Open %@"),
                    locale: .current,
                    ticketID
                ))
                .accessibilityIdentifier("SidebarTicketRow")
        } else {
            label
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("SidebarTicketRow")
        }
    }
}
