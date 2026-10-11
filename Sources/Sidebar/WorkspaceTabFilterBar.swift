import AppKit
import SwiftUI
import BmuxAppKitSupportUI

struct WorkspaceTabFilterBar: View {
    let items: [WorkspaceFilterItem]
    let selectedWorkspaceTitle: String?
    @Binding var filters: WorkspaceFilters
    @Binding var isPanelPresented: Bool
    var onFocusHostChange: @MainActor (NSView, Bool) -> Void = { _, _ in }

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isSearchFocused: Bool
    private var theme: MatteTheme { MatteTheme(colorScheme: colorScheme) }

    private var visibleItems: [WorkspaceFilterItem] {
        WorkspaceTabFilterProjection().visibleItems(items, filters: filters)
    }

    private var isSelectionHidden: Bool {
        guard !filters.isEmpty, let selectedWorkspaceTitle else { return false }
        return !visibleItems.contains { $0.title == selectedWorkspaceTitle }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: theme.layout.smallIconSize))
                        .foregroundStyle(Color(nsColor: theme.color(.textTertiary)))
                    TextField("", text: $filters.query)
                    .focused($isSearchFocused)
                    .textFieldStyle(.plain)
                    .matteTypography(.body, theme: theme)
                    .foregroundStyle(Color(nsColor: theme.color(.textPrimary)))
                    .overlay(alignment: .leading) {
                        if filters.query.isEmpty {
                            Text(String(localized: "sidebar.workspaceFilter.search", defaultValue: "Search workspaces…"))
                                .matteTypography(.body, theme: theme)
                                .foregroundStyle(Color(nsColor: theme.color(.textTertiary)))
                                .lineLimit(1)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel(String(localized: "sidebar.workspaceFilter.search", defaultValue: "Search workspaces…"))
                    if !filters.query.isEmpty {
                        MatteButton(hitExpansion: theme.layout.invisibleHitExpansion) { filters.query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: theme.layout.smallIconSize))
                                .foregroundStyle(Color(nsColor: theme.color(.textTertiary)))
                                .frame(width: theme.layout.minimumHitSize, height: theme.layout.minimumHitSize)
                        }
                        .buttonStyle(MatteButtonStyle(.flat, theme: theme))
                        .accessibilityLabel(String(localized: "sidebar.workspaceFilter.clearSearch", defaultValue: "Clear search"))
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: theme.layout.controlHeight)
                .matteField(theme: theme, isFocused: isSearchFocused)

                MatteButton(hitExpansion: theme.layout.invisibleHitExpansion) { isPanelPresented.toggle() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: theme.layout.smallIconSize))
                        if filters.categoryCount > 0 {
                            Text("\(filters.categoryCount)")
                                .matteTypography(.body, theme: theme)
                        }
                    }
                    .frame(minWidth: theme.layout.raisedHitSize, minHeight: theme.layout.raisedHitSize)
                }
                .buttonStyle(MatteButtonStyle(theme: theme, isSelected: filters.categoryCount > 0 || isPanelPresented))
                .accessibilityAddTraits(filters.categoryCount > 0 || isPanelPresented ? .isSelected : [])
                .accessibilityLabel(String(localized: "sidebar.workspaceFilter.title", defaultValue: "FILTERS"))
                .accessibilityValue(String(format: String(localized: "sidebar.workspaceFilter.activeCount", defaultValue: "%d active filters"), filters.categoryCount))
                .popover(isPresented: $isPanelPresented, arrowEdge: .bottom) {
                    WorkspaceSidebarFocusScope(usesIntrinsicSize: true, onAttachmentChange: onFocusHostChange) {
                        WorkspaceTabFilterPanel(items: items, filters: $filters)
                            .frame(width: 260)
                            .padding(12)
                            .matteSurface(.overlay, theme: theme)
                    }
                }
            }

            if !filters.isEmpty {
                filterPills
                if !visibleItems.isEmpty {
                    Text(String(format: String(localized: "sidebar.workspaceFilter.results", defaultValue: "%d of %d workspaces"), visibleItems.count, items.count))
                        .matteTypography(.body, theme: theme)
                        .foregroundStyle(Color(nsColor: theme.color(.textTertiary)))
                }
                if isSelectionHidden {
                    VStack(alignment: .leading, spacing: 4) {
                        Label {
                            Text(String(format: String(localized: "sidebar.workspaceFilter.hiddenSelection", defaultValue: "%@ is selected but hidden by filters"), selectedWorkspaceTitle ?? ""))
                        } icon: { Image(systemName: "eye.slash").font(.system(size: theme.layout.smallIconSize)) }
                        MatteButton(hitExpansion: theme.layout.invisibleHitExpansion) { filters = WorkspaceFilters() } label: {
                            Text(String(localized: "sidebar.workspaceFilter.showIt", defaultValue: "Show it"))
                                .frame(minWidth: theme.layout.minimumHitSize, minHeight: theme.layout.minimumHitSize)
                        }
                            .buttonStyle(MatteButtonStyle(.link, theme: theme))
                    }
                    .matteTypography(.body, theme: theme)
                    .foregroundStyle(Color(nsColor: theme.color(.textSecondary)))
                    .padding(8)
                    .background(Color(nsColor: theme.color(.hoverWash)), in: RoundedRectangle(cornerRadius: theme.layout.compactControlRadius))
                }
            }
        }
    }

    private var filterPills: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 5)], alignment: .leading, spacing: 5) {
            ForEach(Array(filters.statuses).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { value in
                pill(label: statusLabel(value)) { filters = filters.removing(status: value) }
            }
            ForEach(filters.owners.sorted(), id: \.self) { value in pill(label: value) { filters = filters.removing(owner: value) } }
            ForEach(filters.repos.sorted(), id: \.self) { value in pill(label: value) { filters = filters.removing(repo: value) } }
            ForEach(filters.projects.sorted(), id: \.self) { value in pill(label: value) { filters = filters.removing(project: value) } }
            if !filters.query.isEmpty { pill(label: filters.query) { filters.query = "" } }
        }
    }

    private func pill(label: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label).lineLimit(1)
            MatteButton(hitExpansion: theme.layout.invisibleHitExpansion, action: onRemove) { Image(systemName: "xmark").font(.system(size: theme.layout.smallIconSize)).frame(width: theme.layout.minimumHitSize, height: theme.layout.minimumHitSize) }
                .buttonStyle(MatteButtonStyle(.flat, theme: theme))
                .accessibilityLabel(String(format: String(localized: "sidebar.workspaceFilter.removeFilter", defaultValue: "Remove filter %@"), label))
        }
        .matteTypography(.body, theme: theme)
        .foregroundStyle(Color(nsColor: theme.color(.link)))
        .padding(.leading, 7)
        .background(Color(nsColor: theme.color(.chip)), in: RoundedRectangle(cornerRadius: theme.layout.compactControlRadius))
    }

    private func statusLabel(_ status: WorkspaceStatusKind) -> String {
        switch status {
        case .active: return String(localized: "sidebar.workspaceFilter.status.active", defaultValue: "Active")
        case .waiting: return String(localized: "sidebar.workspaceFilter.status.waiting", defaultValue: "Waiting")
        case .finished: return String(localized: "sidebar.workspaceFilter.status.finished", defaultValue: "Finished")
        case .error: return String(localized: "sidebar.workspaceFilter.status.error", defaultValue: "Error")
        }
    }
}
