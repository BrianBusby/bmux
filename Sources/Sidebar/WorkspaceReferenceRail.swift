import SwiftUI

/// Owns workspace-list projection above the card snapshot boundary.
@MainActor
struct WorkspaceReferenceRail: View {
    let workspaces: [Workspace]
    let cards: [WorkspaceReferenceCardSnapshot]
    let selectedWorkspaceID: UUID?
    let selectedWorkspaceTitle: String?
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onOpenLink: (UUID, URL) -> Void
    @Binding var filters: WorkspaceFilters
    @Binding var isFilterPanelPresented: Bool

    var body: some View {
        WorkspaceRepositoryLabelScope(workspaces: workspaces) { repositoryNames in
            let filterItems = WorkspaceTabFilterProjection().items(for: workspaces)
            let visibleWorkspaceIDs = Set(
                WorkspaceTabFilterProjection().visibleItems(
                    filterItems,
                    filters: filters
                ).map(\.id)
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(String(localized: "workspaceRail.title", defaultValue: "Workspaces"))
                        .font(.system(size: 11, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(Color.workspaceReferenceTextMuted)
                    Spacer()
                    Text(String(workspaces.count))
                        .foregroundStyle(Color.workspaceReferenceTextDisabled)
                }

                WorkspaceTabFilterBar(
                    items: filterItems,
                    selectedWorkspaceTitle: selectedWorkspaceTitle,
                    filters: $filters,
                    isPanelPresented: $isFilterPanelPresented
                )

                ScrollView {
                    let visibleCards = cards.filter { visibleWorkspaceIDs.contains($0.id) }
                    VStack(spacing: 8) {
                        ForEach(visibleCards) { card in
                            let isSelected = card.id == selectedWorkspaceID
                                VStack(alignment: .leading, spacing: 12) {
                                WorkspaceCardHeader(
                                    repositoryName: repositoryNames[card.id],
                                    repositoryFont: .system(size: 10, weight: .medium),
                                    closeIcon: {
                                        Image(systemName: "xmark").font(.system(size: 14, weight: .medium))
                                    },
                                    closeButtonColor: Color.workspaceReferenceTextSecondary,
                                    closeButtonSize: CGSize(width: 20, height: 20),
                                    canCloseWorkspace: workspaces.count > 1,
                                    showsCloseButton: true,
                                    closeButtonTooltip: String(localized: "sidebar.closeWorkspace.tooltip", defaultValue: "Close Workspace"),
                                    onClose: { onClose(card.id) }
                                ) {
                                    Text(card.title)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Color.workspaceReferenceTextPrimary)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                bmuxReferenceWorkspaceLinkRows(for: card)

                                Divider().overlay(Color.workspaceReferenceSeparatorSubtle)

                                VStack(alignment: .leading, spacing: 4) {
                                    if let prompt = card.prompt {
                                        Text(prompt)
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.workspaceReferenceTextSecondary)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    let branch = card.branch
                                    let isDirty = card.isDirty
                                    let status = isDirty.map {
                                        String(
                                            localized: $0 ? "sidebar.workspace.card.uncommittedChanges" : "sidebar.workspace.card.clean",
                                            defaultValue: $0 ? "uncommitted changes" : "clean"
                                        )
                                    }
                                    if branch != nil || status != nil {
                                        Text([branch, status].compactMap { $0 }.joined(separator: " · "))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(Color.workspaceReferenceTextSecondary)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(12)
                            .background(isSelected ? Color.workspaceReferenceCardSelected : Color.workspaceReferenceCard)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                                isSelected ? Color.workspaceReferenceCardSelectedBorder : Color.workspaceReferenceCardBorder,
                                lineWidth: 1
                            ))
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                            .onTapGesture {
                                onSelect(card.id)
                            }
                        }

                        if visibleCards.isEmpty, !filters.isEmpty {
                            WorkspaceTabFilterEmptyState(
                                query: filters.query,
                                hasCategoryFilters: filters.categoryCount > 0,
                                onClear: { filters = WorkspaceFilters() }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .frame(width: 340)
            .background(Color.workspaceReferenceRail)
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color.workspaceReferenceSeparator).frame(width: 1)
            }
        }
    }

    @ViewBuilder
    private func bmuxReferenceWorkspaceLinkRows(for card: WorkspaceReferenceCardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let ticketID = card.ticketID {
                let ticketContent = HStack(spacing: 6) {
                    Image(systemName: "ticket")
                        .font(.system(size: 11, weight: .medium))
                    Text(ticketID)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(Color.workspaceReferenceTextSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.workspaceReferenceTextSecondary.opacity(0.35), lineWidth: 1)
                }
                if let ticketURL = card.ticketURL {
                    Button {
                        onOpenLink(card.id, ticketURL)
                    } label: {
                        ticketContent
                    }
                    .buttonStyle(.plain)
                } else {
                    ticketContent
                }
            }

            if let projectTitle = card.projectTitle {
                bmuxReferenceWorkspaceLinkRow(
                    icon: "folder",
                    text: projectTitle,
                    url: card.projectURL,
                    card: card,
                    color: Color.workspaceReferenceTextPrimary
                )
            }

            if let summary = card.summary {
                Text(String(summary.prefix(125)))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.workspaceReferenceTextSecondary)
                    .lineLimit(3)
                    .truncationMode(.tail)
            }

            if let pullRequestText = card.pullRequestText {
                bmuxReferenceWorkspaceLinkRow(
                    icon: "arrow.triangle.pull",
                    text: pullRequestText,
                    url: card.pullRequestURL,
                    card: card,
                    color: card.pullRequestURL == nil ? Color.workspaceReferenceTextPrimary : bmuxAccentColor()
                )
            }

            if let ownerName = card.ownerName {
                let ownerContent = HStack(spacing: 8) {
                    Text(ownerName.prefix(2).uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.workspaceReferenceTextPrimary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.workspaceReferenceTextSecondary.opacity(0.18)))
                    Text(ownerName)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.workspaceReferenceTextSecondary)
                }
                if let ownerURL = card.ownerURL {
                    Button {
                        onOpenLink(card.id, ownerURL)
                    } label: {
                        ownerContent
                    }
                    .buttonStyle(.plain)
                } else {
                    ownerContent
                }
            }
        }
    }

    @ViewBuilder
    private func bmuxReferenceWorkspaceLinkRow(
        icon: String,
        text: String,
        url: URL?,
        card: WorkspaceReferenceCardSnapshot,
        color: Color = Color.workspaceReferenceTextSecondary
    ) -> some View {
        let row = HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .frame(width: 13)
            Text(text)
                .underline(url != nil)
                .lineLimit(2)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .font(.system(size: 13))
        .foregroundStyle(color)
        .contentShape(Rectangle())

        if let url {
            Button {
                onOpenLink(card.id, url)
            } label: {
                row
            }
            .buttonStyle(.plain)
        } else {
            row
        }
    }

}
