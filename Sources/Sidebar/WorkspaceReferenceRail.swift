import AppKit
import SwiftUI
import BmuxAppKitSupportUI

/// Owns workspace-list projection above the card snapshot boundary.
@MainActor
struct WorkspaceReferenceRail: View {
    let workspaces: [Workspace]
    let projectCard: @MainActor (Workspace) -> WorkspaceReferenceCardSnapshot
    let selectedWorkspaceID: UUID?
    let selectedWorkspaceTitle: String?
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onOpenLink: (UUID, URL) -> Void
    let onLaunchRepository: (NSView) -> Void
    let onFocusHostChange: @MainActor (NSView, WorkspaceSidebarFocusOwner.Scope, Bool) -> Void
    @Environment(\.colorScheme) private var colorScheme
    private var theme: MatteTheme { MatteTheme(colorScheme: colorScheme) }

    @Binding var filters: WorkspaceFilters
    @Binding var isFilterPanelPresented: Bool
    @State private var repoLauncherAnchorView: NSView?

    var body: some View {
        WorkspaceSidebarFocusScope(usesIntrinsicSize: false, onAttachmentChange: {
            onFocusHostChange($0, .rail, $1)
        }) {
            WorkspaceReferenceCardScope(workspaces: workspaces, project: projectCard) { cards in
                cardContent(cards: cards)
            }
            .padding(.horizontal, theme.layout.windowGutter)
        }
        // Native hosting bounds must include the existing gutter for control
        // hit outsets and card shadows; compensate to retain the rail layout.
        .padding(.horizontal, -theme.layout.windowGutter)
    }

    private func cardContent(cards: [WorkspaceReferenceCardSnapshot]) -> some View {
        WorkspaceRepositoryLabelScope(workspaces: workspaces) { repositoryNames in
            let filterItems = WorkspaceTabFilterProjection().items(for: workspaces, cards: cards)
            let visibleWorkspaceIDs = Set(
                WorkspaceTabFilterProjection().visibleItems(
                    filterItems,
                    filters: filters
                ).map(\.id)
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(String(
                        format: String(
                            localized: workspaces.count == 1 ? "workspaceRail.count.one" : "workspaceRail.count.other",
                            defaultValue: workspaces.count == 1 ? "%lld Workspace" : "%lld Workspaces"
                        ),
                        Int64(workspaces.count)
                    ))
                        .textCase(.uppercase)
                        .matteTypography(.sectionLabel, theme: theme)
                        .foregroundStyle(Color(nsColor: theme.color(.textSecondary)))
                    Spacer()
                    MatteButton(hitExpansion: theme.layout.invisibleHitExpansion) {
                        guard let repoLauncherAnchorView else {
                            NSSound.beep()
                            return
                        }
                        onLaunchRepository(repoLauncherAnchorView)
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: theme.layout.smallIconSize, weight: .medium))
                            .frame(width: theme.layout.raisedHitSize, height: theme.layout.raisedHitSize)
                    }
                    .buttonStyle(MatteButtonStyle(theme: theme))
                    .background(TitlebarControlAnchorView { repoLauncherAnchorView = $0 })
                    .accessibilityIdentifier("bmuxShell.repoAgentLauncher")
                    .accessibilityLabel(String(localized: "titlebar.repoAgentLauncher.accessibilityLabel", defaultValue: "AI Repo Launcher"))
                    .safeHelp(String(localized: "titlebar.repoAgentLauncher.tooltip", defaultValue: "Launch an AI session for a repo"))
                }

                WorkspaceTabFilterBar(
                    items: filterItems,
                    selectedWorkspaceTitle: selectedWorkspaceTitle,
                    filters: $filters,
                    isPanelPresented: $isFilterPanelPresented,
                    onFocusHostChange: { onFocusHostChange($0, .filterPopover, $1) }
                )

                ScrollView {
                    let visibleCards = cards.filter { visibleWorkspaceIDs.contains($0.id) }
                    VStack(spacing: theme.layout.cardGap) {
                        ForEach(visibleCards) { card in
                            WorkspaceReferenceCardView(
                                card: card, repositoryName: repositoryNames[card.id],
                                isSelected: card.id == selectedWorkspaceID,
                                canCloseWorkspace: workspaces.count > 1,
                                onSelect: { onSelect(card.id) }, onClose: { onClose(card.id) },
                                onOpenLink: { onOpenLink(card.id, $0) }
                            )
                        }

                        if visibleCards.isEmpty, !filters.isEmpty {
                            WorkspaceTabFilterEmptyState(
                                query: filters.query,
                                hasCategoryFilters: filters.categoryCount > 0,
                                onClear: { filters = WorkspaceFilters() }
                            )
                        }
                    }
                    .padding(.horizontal, theme.layout.windowGutter)
                    .padding(.top, theme.layout.focusOutlineWidth + theme.layout.focusOutlineOffset)
                    .padding(.bottom, max(theme.layout.windowGutter, theme.shadows(.ambientTwo).map { $0.offsetY + $0.blur / 2 + $0.spread }.max() ?? 0))
                }
                .padding(.horizontal, -theme.layout.windowGutter)
            }
            .padding(.top, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
