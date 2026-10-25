import AppKit
import SwiftUI

/// Recursive display of one immutable grouping branch and its card snapshots.
struct WorkspaceExplorerGroupSection: View {
    let group: WorkspaceExplorerGroup
    let depth: Int
    let path: String
    let cardGeometry: Namespace.ID
    let overview: Bool
    let collapsedPaths: Set<String>
    let activeFilters: [WorkspaceExplorerDimension: WorkspaceExplorerGroupKey]
    let groupedDimensions: Set<WorkspaceExplorerDimension>
    let projectsByID: [String: WorkspaceExplorerProject]
    let repositoryNamesByID: [String: String]
    let itemsByID: [String: WorkspaceExplorerHistoryItem]
    let workspacesByID: [String: WorkspaceExplorerWorkspace]
    let projectCounts: [String: WorkspaceExplorerCounts]
    let projectOpenTotals: [String: Int]
    let scope: WorkspaceExplorerScope
    let now: Date
    let calendar: Calendar
    let archiveAvailability: WorkspaceExplorerArchiveAvailability
    let matchingCounts: [String: Int]
    let exitingProjectIDs: Set<String>
    let exitingWorkspaceIDs: Set<String>
    let focusedProjectID: String?
    let activeWorkspaceID: String?
    let reopenedWorkspaceID: String?
    let metadataPending: Bool
    let onOpenProject: (String) -> Void
    let onOpenWorkspace: (WorkspaceExplorerHistoryItem) -> Void
    let onHistory: (WorkspaceExplorerHistoryItem) -> Void
    let onReopen: (WorkspaceExplorerHistoryItem) -> Void
    let onCardFilter: (WorkspaceExplorerDimension, WorkspaceExplorerGroupKey) -> Void
    let onToggle: (String) -> Void
    let onFocus: (WorkspaceExplorerDimension, WorkspaceExplorerGroupKey) -> Void
    let onCardInteractionChanged: (String, Bool) -> Void
    @FocusState private var disclosureFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let dimension = group.dimension {
                HStack(spacing: 8) {
                    Button {
                        onToggle(path)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: collapsedPaths.contains(path) ? "chevron.right" : "chevron.down")
                            Text(label)
                                .textCase(depth >= 2 ? .uppercase : nil)
                            Text(groupCount).foregroundStyle(.primary)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color(nsColor: .controlColor), in: Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .focused($disclosureFocused)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(disclosureFocused ? Color.accentColor : .clear, lineWidth: 2)
                            .padding(-3).allowsHitTesting(false)
                    }
                    .accessibilityLabel(String(format: String(localized: "explorer.groupDisclosureLabel",
                        defaultValue: "%1$@: %2$@, %3$@"), dimension.displayName, label, groupCount))
                    .accessibilityValue(collapsedPaths.contains(path) ?
                        String(localized: "explorer.collapsed", defaultValue: "Collapsed") :
                        String(localized: "explorer.expanded", defaultValue: "Expanded"))
                    .font(.system(size: depth == 0 ? 15 : depth == 1 ? 13 : 11,
                        weight: depth == 0 ? .bold : .semibold))
                    if let key = group.filterValue, activeFilters[dimension] != key {
                        Button(String(localized: "explorer.focus", defaultValue: "Focus")) {
                            onFocus(dimension, key)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityLabel(String(format: String(localized: "explorer.focusGroup",
                            defaultValue: "Focus on %1$@ in %2$@"), label, dimension.displayName))
                    }
                    Spacer()
                }
                if depth >= 2 { Divider() }
            }
            if !collapsedPaths.contains(path) {
                if group.children.isEmpty {
                    cardGrid
                } else {
                    ForEach(group.children, id: \.identity) { child in
                        WorkspaceExplorerGroupSection(group: child, depth: depth + 1,
                            path: path + "/" + child.identity,
                            cardGeometry: cardGeometry,
                            overview: overview, collapsedPaths: collapsedPaths,
                            activeFilters: activeFilters, groupedDimensions: groupedDimensions,
                            projectsByID: projectsByID, repositoryNamesByID: repositoryNamesByID,
                            itemsByID: itemsByID, workspacesByID: workspacesByID,
                            projectCounts: projectCounts,
                            projectOpenTotals: projectOpenTotals, scope: scope, now: now, calendar: calendar,
                            archiveAvailability: archiveAvailability,
                            matchingCounts: matchingCounts,
                            exitingProjectIDs: exitingProjectIDs, exitingWorkspaceIDs: exitingWorkspaceIDs,
                            focusedProjectID: focusedProjectID,
                            activeWorkspaceID: activeWorkspaceID,
                            reopenedWorkspaceID: reopenedWorkspaceID,
                            metadataPending: metadataPending,
                            onOpenProject: onOpenProject, onOpenWorkspace: onOpenWorkspace,
                            onHistory: onHistory, onReopen: onReopen,
                            onCardFilter: onCardFilter, onToggle: onToggle, onFocus: onFocus,
                            onCardInteractionChanged: onCardInteractionChanged)
                    }
                }
            }
        }
        .id(path)
        .padding(depth == 0 && group.dimension != nil ? 12 : 0)
        .padding(.leading, depth == 1 && group.dimension != nil ? 12 : 0)
        .background(depth == 0 && group.dimension != nil ? Color(nsColor: .controlBackgroundColor).opacity(0.45) : .clear,
            in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            if depth == 0 && group.dimension != nil {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            }
        }
        .overlay(alignment: .leading) {
            if depth == 1 && group.dimension != nil {
                Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 2)
            }
        }
    }

    private var cardGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: overview ? 250 : 236), spacing: overview ? 12 : 10)],
                  spacing: overview ? 12 : 10) {
            if overview {
                ForEach(group.projectIDs, id: \.self) { id in
                    if let project = projectsByID[id] {
                        WorkspaceExplorerProjectCard(project: project,
                            counts: projectCounts[id] ?? WorkspaceExplorerCounts([], closedKnown: false),
                            workspaces: workspacesByID.values.filter { workspace in
                                workspace.projectIDs.contains(id) && scope.includes(workspace,
                                    now: now, calendar: calendar)
                            },
                            repositoryNamesByID: repositoryNamesByID,
                            scope: scope, archiveAvailability: archiveAvailability,
                            openTotal: projectOpenTotals[id] ?? 0,
                            matchingCount: matchingCounts[id],
                            isFocused: focusedProjectID == id, titleGeometry: cardGeometry,
                            onOpen: { onOpenProject(id) },
                            onInteractionChanged: { onCardInteractionChanged("project:\(id)", $0) })
                            .id("project:\(id)")
                            .matchedGeometryEffect(id: "project:\(id)", in: cardGeometry)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            .opacity(exitingProjectIDs.contains(id) ? 0 : 1)
                            .allowsHitTesting(!exitingProjectIDs.contains(id))
                            .accessibilityHidden(exitingProjectIDs.contains(id))
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.17), value: exitingProjectIDs.contains(id))
                    }
                }
            } else {
                ForEach(group.workspaceIDs, id: \.self) { id in
                    if let item = itemsByID[id] {
                        WorkspaceExplorerWorkspaceCard(item: item, isActive: activeWorkspaceID == id,
                            isReopened: reopenedWorkspaceID == id,
                            repositoryName: item.display?.repositoryID.flatMap { repositoryNamesByID[$0] },
                            metadataPending: metadataPending,
                            arrangedStatus: workspacesByID[id]?.arrangedStatus,
                            hiddenDimensions: groupedDimensions.union(activeFilters.keys),
                            onOpen: { onOpenWorkspace(item) },
                            onHistory: { onHistory(item) },
                            onReopen: { onReopen(item) },
                            onFilter: onCardFilter,
                            onInteractionChanged: { onCardInteractionChanged("workspace:\(id)", $0) })
                            .id("workspace:\(id)")
                            .matchedGeometryEffect(id: "workspace:\(id)", in: cardGeometry)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            .opacity(exitingWorkspaceIDs.contains(id) ? 0 : 1)
                            .allowsHitTesting(!exitingWorkspaceIDs.contains(id))
                            .accessibilityHidden(exitingWorkspaceIDs.contains(id))
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.17), value: exitingWorkspaceIDs.contains(id))
                    }
                }
            }
        }
        .scrollTargetLayout()
    }

    private var groupCount: String {
        if overview {
            if scope.state == .all && group.counts.closedKnown {
                return String(format: String(localized: "explorer.overviewGroupBreakdown", defaultValue:
                    "%d projects · %d in scope (%d open · %d closed)"), group.projectIDs.count,
                    group.counts.workspaces, group.counts.open, group.counts.closed)
            }
            return String(format: String(localized: "explorer.overviewGroupCount", defaultValue:
                "%d projects · %d in scope"), group.projectIDs.count, group.counts.workspaces)
        }
        if scope.state == .all && group.counts.closedKnown {
            return String(format: String(localized: "explorer.workspaceGroupBreakdown", defaultValue:
                "%d · %d open · %d closed"), group.counts.workspaces,
                group.counts.open, group.counts.closed)
        }
        return group.counts.workspaces.formatted()
    }

    private var label: String {
        group.key?.displayName(projectsByID: projectsByID,
            repositoryNamesByID: group.dimension == .repository ? repositoryNamesByID : [:]) ?? group.value ?? ""
    }
}
