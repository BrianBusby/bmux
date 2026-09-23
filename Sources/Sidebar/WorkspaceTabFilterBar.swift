import SwiftUI

struct WorkspaceTabFilterBar: View {
    let items: [WorkspaceFilterItem]
    let selectedWorkspaceTitle: String?
    @Binding var filters: WorkspaceFilters
    @Binding var isPanelPresented: Bool

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
                        .foregroundStyle(Color.white.opacity(0.28))
                    TextField(
                        String(localized: "sidebar.workspaceFilter.search", defaultValue: "Search workspaces…"),
                        text: $filters.query
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    if !filters.query.isEmpty {
                        Button { filters.query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.white.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12)))

                Button { isPanelPresented.toggle() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease")
                        if filters.categoryCount > 0 {
                            Text("\(filters.categoryCount)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                    }
                    .foregroundStyle(filters.categoryCount > 0 || isPanelPresented ? Color.green.opacity(0.8) : Color.white.opacity(0.35))
                    .frame(width: 58, height: 38)
                    .background((filters.categoryCount > 0 || isPanelPresented) ? Color.green.opacity(0.12) : Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isPanelPresented, arrowEdge: .bottom) {
                    WorkspaceTabFilterPanel(items: items, filters: $filters)
                        .frame(width: 260)
                        .padding(12)
                    }
            }

            if !filters.isEmpty {
                filterPills
                if !visibleItems.isEmpty {
                    Text(String(format: String(localized: "sidebar.workspaceFilter.results", defaultValue: "%d of %d workspaces"), visibleItems.count, items.count))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.28))
                }
                if isSelectionHidden {
                    VStack(alignment: .leading, spacing: 4) {
                        Label {
                            Text(String(format: String(localized: "sidebar.workspaceFilter.hiddenSelection", defaultValue: "%@ is selected but hidden by filters"), selectedWorkspaceTitle ?? ""))
                        } icon: { Image(systemName: "eye.slash") }
                        Button(String(localized: "sidebar.workspaceFilter.showIt", defaultValue: "Show it")) { filters = WorkspaceFilters() }
                            .buttonStyle(.link)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .padding(8)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var filterPills: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 5)], alignment: .leading, spacing: 5) {
            ForEach(Array(filters.statuses).sorted(by: { lhs, rhs in lhs.rawValue < rhs.rawValue }), id: \.self) { value in
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
            Button(action: onRemove) { Image(systemName: "xmark") }.buttonStyle(.plain)
        }
        .font(.system(size: 11))
        .foregroundStyle(Color.green.opacity(0.8))
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
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

struct WorkspaceTabFilterEmptyState: View {
    let query: String
    let hasCategoryFilters: Bool
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22))
                .foregroundStyle(Color.white.opacity(0.16))
            Text(String(localized: "sidebar.workspaceFilter.empty.title", defaultValue: "No workspaces match"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.32))
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.22))
                .multilineTextAlignment(.center)
            Button(String(localized: "sidebar.workspaceFilter.clearAll", defaultValue: "Clear all filters"), action: onClear)
                .buttonStyle(.link)
                .font(.system(size: 11))
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding(.horizontal, 20)
    }

    private var message: String {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, hasCategoryFilters {
            return String(format: String(localized: "sidebar.workspaceFilter.empty.combined", defaultValue: "No results for \"%@\" with these filters."), query)
        }
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(format: String(localized: "sidebar.workspaceFilter.empty.query", defaultValue: "No results for \"%@\". Try a branch name, PR number, or ticket ID."), query)
        }
        return String(localized: "sidebar.workspaceFilter.empty.filters", defaultValue: "No workspaces match the selected filters.")
    }
}

private struct WorkspaceTabFilterPanel: View {
    let items: [WorkspaceFilterItem]
    @Binding var filters: WorkspaceFilters

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "sidebar.workspaceFilter.title", defaultValue: "FILTERS"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.35))
                Spacer()
                if !filters.isEmpty {
                    Button(String(localized: "sidebar.workspaceFilter.clearAll", defaultValue: "Clear all")) { filters = WorkspaceFilters() }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                }
            }
            section(String(localized: "sidebar.workspaceFilter.status", defaultValue: "STATUS")) {
                ForEach(WorkspaceStatusKind.allCases.filter { status in items.contains { item in item.status == status } }, id: \.self) { status in
                    checkbox(statusLabel(status), isOn: filters.statuses.contains(status)) {
                        if filters.statuses.contains(status) { filters.statuses.remove(status) } else { filters.statuses.insert(status) }
                    }
                }
            }
            dynamicSection(String(localized: "sidebar.workspaceFilter.repository", defaultValue: "REPOSITORY"), values: WorkspaceTabFilterProjection().values(for: \.repo, in: items), selection: $filters.repos)
            dynamicSection(String(localized: "sidebar.workspaceFilter.project", defaultValue: "PROJECT"), values: WorkspaceTabFilterProjection().values(for: \.project, in: items), selection: $filters.projects)
            Text(String(localized: "sidebar.workspaceFilter.hint", defaultValue: "Search also matches branch names, PR numbers, and ticket IDs"))
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.24))
        }
    }

    @ViewBuilder private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.white.opacity(0.3)); content() }
    }

    private func dynamicSection(_ title: String, values: [String], selection: Binding<Set<String>>) -> some View {
        Group {
            if !values.isEmpty { section(title) { ForEach(values, id: \.self) { value in checkbox(value, isOn: selection.wrappedValue.contains(value)) { if selection.wrappedValue.contains(value) { selection.wrappedValue.remove(value) } else { selection.wrappedValue.insert(value) } } } } }
        }
    }

    private func checkbox(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: isOn ? "checkmark.square.fill" : "square").font(.system(size: 12)).foregroundStyle(isOn ? Color.green.opacity(0.8) : Color.white.opacity(0.65)) }.buttonStyle(.plain)
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
