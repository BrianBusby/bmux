import SwiftUI

extension TabItemView {
    @ViewBuilder
    func ticketRowsView(_ rows: [SidebarWorkspaceSnapshotBuilder.TicketDisplay]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(rows) { ticket in
                let linkText = ticket.linkText
                let rowContent = HStack(spacing: 4) {
                    BmuxSystemSymbolImage(magnified: "ticket", pointSize: scaledFontSize(9), weight: .medium)
                        .foregroundColor(activeSecondaryColor(0.72))
                    Text(linkText)
                        .underline(ticket.url != nil)
                        .foregroundColor(ticket.url == nil ? activeSecondaryColor(0.75) : pullRequestLinkColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .font(magnifiedFont(scaledFontSize(10), weight: .semibold, design: .monospaced))
                .foregroundColor(activeSecondaryColor(0.75))
                if let url = ticket.url {
                    Button(action: { openTicketLink(url) }) { rowContent }
                        .buttonStyle(.plain)
                        .tint(activeSecondaryColor(0.75))
                        .safeHelp(String(
                            format: String(
                                localized: "sidebar.ticket.openTooltip",
                                defaultValue: "Open %@"
                            ),
                            locale: .current,
                            linkText
                        ))
                        .accessibilityIdentifier("SidebarTicketRow")
                } else {
                    rowContent.accessibilityElement(children: .combine).accessibilityIdentifier("SidebarTicketRow")
                }
                if let ownerName = ticket.ownerName {
                    ticketOwnerRowView(ticket, ownerName: ownerName)
                }
            }
        }
    }

    @ViewBuilder
    private func ticketOwnerRowView(
        _ ticket: SidebarWorkspaceSnapshotBuilder.TicketDisplay,
        ownerName: String
    ) -> some View {
        let ownerContent = HStack(spacing: 4) {
            BmuxSystemSymbolImage(magnified: "person.crop.circle", pointSize: scaledFontSize(9), weight: .medium)
                .foregroundColor(activeSecondaryColor(0.72))
            Text(ownerName)
                .underline(ticket.ownerURL != nil)
                .foregroundColor(ticket.ownerURL == nil ? activeSecondaryColor(0.75) : pullRequestLinkColor)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .font(magnifiedFont(scaledFontSize(10), weight: .semibold))
        .foregroundColor(activeSecondaryColor(0.75))
        if let ownerURL = ticket.ownerURL {
            Button(action: { openTicketLink(ownerURL) }) { ownerContent }
                .buttonStyle(.plain)
                .tint(activeSecondaryColor(0.75))
                .safeHelp(String(
                    format: String(
                        localized: "sidebar.ticket.owner.openTooltip",
                        defaultValue: "Open %@"
                    ),
                    locale: .current,
                    ownerName
                ))
                .accessibilityIdentifier("SidebarTicketOwnerRow")
        } else {
            ownerContent.accessibilityElement(children: .combine).accessibilityIdentifier("SidebarTicketOwnerRow")
        }
    }
}
