import SwiftUI
import BmuxAppKitSupportUI

struct WorkspaceTabFilterPanel: View {
    let items: [WorkspaceFilterItem]
    @Binding var filters: WorkspaceFilters

    @Environment(\.colorScheme) private var colorScheme
    private var theme: MatteTheme { MatteTheme(colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "sidebar.workspaceFilter.title", defaultValue: "FILTERS"))
                    .matteTypography(.sectionLabel, theme: theme)
                    .foregroundStyle(Color(nsColor: theme.color(.textTertiary)))
                Spacer()
                if !filters.isEmpty {
                    MatteButton(hitExpansion: theme.layout.invisibleHitExpansion) { filters = WorkspaceFilters() } label: {
                        Text(String(localized: "sidebar.workspaceFilter.clearAll", defaultValue: "Clear all"))
                            .frame(minWidth: theme.layout.minimumHitSize, minHeight: theme.layout.minimumHitSize)
                    }
                        .buttonStyle(MatteButtonStyle(.link, theme: theme))
                        .matteTypography(.body, theme: theme)
                }
            }
            section(String(localized: "sidebar.workspaceFilter.status", defaultValue: "STATUS")) {
                ForEach(WorkspaceStatusKind.allCases.filter { status in items.contains { $0.status == status } }, id: \.self) { status in
                    checkbox(statusLabel(status), isOn: filters.statuses.contains(status)) {
                        if filters.statuses.contains(status) { filters.statuses.remove(status) } else { filters.statuses.insert(status) }
                    }
                }
            }
            dynamicSection(String(localized: "sidebar.workspaceFilter.repository", defaultValue: "REPOSITORY"), values: WorkspaceTabFilterProjection().values(for: \.repo, in: items), selection: $filters.repos)
            dynamicSection(String(localized: "sidebar.workspaceFilter.project", defaultValue: "PROJECT"), values: WorkspaceTabFilterProjection().values(for: \.project, in: items), selection: $filters.projects)
            dynamicSection(String(localized: "sidebar.workspaceFilter.prOwner", defaultValue: "PR OWNER"), values: WorkspaceTabFilterProjection().values(for: \.owner, in: items), selection: $filters.owners)
            Text(String(localized: "sidebar.workspaceFilter.hint", defaultValue: "Search also matches branch names, PR numbers, and ticket IDs"))
                .matteTypography(.body, theme: theme)
                .foregroundStyle(Color(nsColor: theme.color(.textTertiary)))
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .matteTypography(.sectionLabel, theme: theme)
                .foregroundStyle(Color(nsColor: theme.color(.textTertiary)))
            content()
        }
    }

    private func dynamicSection(_ title: String, values: [String], selection: Binding<Set<String>>) -> some View {
        Group {
            if !values.isEmpty {
                section(title) {
                    ForEach(values, id: \.self) { value in
                        checkbox(value, isOn: selection.wrappedValue.contains(value)) {
                            if selection.wrappedValue.contains(value) {
                                selection.wrappedValue.remove(value)
                            } else {
                                selection.wrappedValue.insert(value)
                            }
                        }
                    }
                }
            }
        }
    }

    private func checkbox(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        MatteButton(hitExpansion: theme.layout.invisibleHitExpansion, action: action) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: theme.layout.smallIconSize))
            }
            .matteTypography(.body, theme: theme)
            .foregroundStyle(Color(nsColor: theme.color(isOn ? .link : .textSecondary)))
            .frame(minWidth: theme.layout.minimumHitSize, minHeight: theme.layout.minimumHitSize)
        }
        .buttonStyle(MatteButtonStyle(.flat, theme: theme))
        .accessibilityAddTraits(isOn ? .isSelected : [])
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
