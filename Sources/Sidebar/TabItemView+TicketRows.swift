import SwiftUI

extension TabItemView {
    @ViewBuilder
    func ticketRowsView(
        _ rows: [SidebarWorkspaceSnapshotBuilder.TicketDisplay],
        prominent: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(rows) { ticket in
                let linkText = ticket.linkText
                let fontSize = prominent ? scaledFontSize(11.5) : scaledFontSize(10)
                let fontWeight: Font.Weight = prominent ? .bold : .semibold
                let linkedTitleLineLimit = SidebarWorkspaceRowLineLimitPolicy.linkedTitleLineLimit(
                    wrapsWorkspaceTitles: settings.wrapsWorkspaceTitles
                )
                let rowContent = HStack(alignment: .top, spacing: 4) {
                    BmuxSystemSymbolImage(magnified: "ticket", pointSize: scaledFontSize(prominent ? 10 : 9), weight: .medium)
                        .foregroundColor(activeSecondaryColor(0.72))
                    Text(linkText)
                        .underline(ticket.url != nil)
                        .foregroundColor(ticket.url == nil ? activeSecondaryColor(0.75) : pullRequestLinkColor)
                        .lineLimit(linkedTitleLineLimit)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(magnifiedFont(fontSize, weight: fontWeight, design: .monospaced))
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
                if let ownerName = ticket.ownerName?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !ownerName.isEmpty {
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
        let rowContent = HStack(spacing: 4) {
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
        if let url = ticket.ownerURL {
            Button(action: { openTicketLink(url) }) { rowContent }
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
            rowContent
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("SidebarTicketOwnerRow")
        }
    }
}
