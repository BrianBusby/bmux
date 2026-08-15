import SwiftUI

extension TabItemView {
    var provenanceTicketDisplays: [SidebarWorkspaceSnapshotBuilder.TicketDisplay] {
        provenanceDisplaySnapshot?.ticketLinks.map {
            SidebarWorkspaceSnapshotBuilder.TicketDisplay(
                id: $0.id,
                title: $0.title,
                url: $0.url
            )
        } ?? []
    }

    var provenanceProjectDisplays: [SidebarWorkspaceSnapshotBuilder.ProjectDisplay] {
        provenanceDisplaySnapshot?.projectLinks.map {
            SidebarWorkspaceSnapshotBuilder.ProjectDisplay(
                id: $0.id,
                title: $0.title,
                url: $0.url
            )
        } ?? []
    }

    @ViewBuilder
    func projectRowsView(_ rows: [SidebarWorkspaceSnapshotBuilder.ProjectDisplay]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(rows) { project in
                let linkText = project.linkText
                let rowContent = HStack(spacing: 4) {
                    BmuxSystemSymbolImage(magnified: "folder", pointSize: scaledFontSize(9), weight: .medium)
                        .foregroundColor(activeSecondaryColor(0.72))
                    Text(linkText)
                        .underline(project.url != nil)
                        .foregroundColor(project.url == nil ? activeSecondaryColor(0.75) : pullRequestLinkColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .font(magnifiedFont(scaledFontSize(10), weight: .semibold))
                .foregroundColor(activeSecondaryColor(0.75))
                if let url = project.url {
                    Button(action: { openTicketLink(url) }) { rowContent }
                        .buttonStyle(.plain)
                        .tint(activeSecondaryColor(0.75))
                        .safeHelp(String(
                            format: String(
                                localized: "sidebar.project.openTooltip",
                                defaultValue: "Open %@"
                            ),
                            locale: .current,
                            linkText
                        ))
                        .accessibilityIdentifier("SidebarProjectRow")
                } else {
                    rowContent.accessibilityElement(children: .combine).accessibilityIdentifier("SidebarProjectRow")
                }
            }
        }
    }
}
