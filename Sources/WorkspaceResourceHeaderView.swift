import SwiftUI
import AppKit
import BmuxAppKitSupportUI

struct WorkspaceResourceHeaderView: View {
    let resources: SidebarWorkspaceSnapshotBuilder.ResourceLinkPresentation
    let onOpen: (SidebarWorkspaceSnapshotBuilder.ResourceLinkPresentation.HeaderItem) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if resources.hasHeaderItems {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(resources.headerItems) { item in
                        Button {
                            onOpen(item)
                        } label: {
                            HStack(spacing: 4) {
                                BmuxSystemSymbolImage(magnified: symbolName(for: item.kind), pointSize: 10, weight: .medium)
                                    .foregroundColor(.secondary)
                                Text(labelText(for: item.kind))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text(item.text)
                                    .font(.system(size: 10, weight: .semibold, design: item.kind == .ticket ? .monospaced : .default))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.55 : 0.78))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color(nsColor: .separatorColor).opacity(0.36), lineWidth: 0.75)
                            )
                        }
                        .buttonStyle(.plain)
                        .safeHelp(openTooltip(for: item))
                        .accessibilityLabel(accessibilityLabel(for: item))
                        .accessibilityIdentifier(accessibilityIdentifier(for: item.kind))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.20 : 0.32))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.32))
                    .frame(height: 1)
            }
            .accessibilityIdentifier("WorkspaceResourceHeader")
        }
    }

    private func symbolName(for kind: SidebarWorkspaceSnapshotBuilder.ResourceLinkPresentation.HeaderKind) -> String {
        switch kind {
        case .ticket: return "ticket"
        case .pullRequest: return "arrow.triangle.branch"
        case .project: return "folder"
        case .owner: return "person.crop.circle"
        }
    }

    private func labelText(for kind: SidebarWorkspaceSnapshotBuilder.ResourceLinkPresentation.HeaderKind) -> String {
        switch kind {
        case .ticket:
            return String(localized: "workspace.header.ticket.label", defaultValue: "Ticket")
        case .pullRequest:
            return String(localized: "workspace.header.pullRequest.label", defaultValue: "PR")
        case .project:
            return String(localized: "workspace.header.project.label", defaultValue: "Project")
        case .owner:
            return String(localized: "workspace.header.owner.label", defaultValue: "Owner")
        }
    }

    private func accessibilityLabel(for item: SidebarWorkspaceSnapshotBuilder.ResourceLinkPresentation.HeaderItem) -> String {
        switch item.kind {
        case .ticket:
            return String(
                format: String(localized: "workspace.header.ticket.accessibilityLabel", defaultValue: "Ticket %@"),
                locale: .current,
                item.text
            )
        case .pullRequest:
            return String(
                format: String(localized: "workspace.header.pullRequest.accessibilityLabel", defaultValue: "Pull request %@"),
                locale: .current,
                item.text
            )
        case .project:
            return String(
                format: String(localized: "workspace.header.project.accessibilityLabel", defaultValue: "Project %@"),
                locale: .current,
                item.text
            )
        case .owner:
            return String(
                format: String(localized: "workspace.header.owner.accessibilityLabel", defaultValue: "Owner %@"),
                locale: .current,
                item.text
            )
        }
    }

    private func accessibilityIdentifier(for kind: SidebarWorkspaceSnapshotBuilder.ResourceLinkPresentation.HeaderKind) -> String {
        switch kind {
        case .ticket: return "WorkspaceHeaderTicketLink"
        case .pullRequest: return "WorkspaceHeaderPullRequestLink"
        case .project: return "WorkspaceHeaderProjectLink"
        case .owner: return "WorkspaceHeaderOwnerLink"
        }
    }

    private func openTooltip(for item: SidebarWorkspaceSnapshotBuilder.ResourceLinkPresentation.HeaderItem) -> String {
        String(
            format: String(localized: "workspace.header.openTooltip", defaultValue: "Open %@"),
            locale: .current,
            item.text
        )
    }
}

extension WorkspaceContentView {
    func openHeaderResource(_ item: SidebarWorkspaceSnapshotBuilder.ResourceLinkPresentation.HeaderItem) {
        BrowserExternalLinkOpener().openWebLink(item.url)
    }
}
