import SwiftUI
import BmuxAppKitSupportUI

struct WorkspaceTabFilterEmptyState: View {
    let query: String
    let hasCategoryFilters: Bool
    let onClear: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var theme: MatteTheme { MatteTheme(colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22))
                .foregroundStyle(Color(nsColor: theme.color(.textTertiary)))
            Text(String(localized: "sidebar.workspaceFilter.empty.title", defaultValue: "No workspaces match"))
                .matteTypography(.body, theme: theme)
                .foregroundStyle(Color(nsColor: theme.color(.textTertiary)))
            Text(message)
                .matteTypography(.body, theme: theme)
                .foregroundStyle(Color(nsColor: theme.color(.textTertiary)))
                .multilineTextAlignment(.center)
            MatteButton(hitExpansion: theme.layout.invisibleHitExpansion, action: onClear) {
                Text(String(localized: "sidebar.workspaceFilter.clearAll", defaultValue: "Clear all filters"))
                    .frame(minWidth: theme.layout.minimumHitSize, minHeight: theme.layout.minimumHitSize)
            }
                .buttonStyle(MatteButtonStyle(.link, theme: theme))
                .matteTypography(.body, theme: theme)
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
