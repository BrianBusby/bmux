import SwiftUI

/// Reports whether retained workspaces can be counted while open cards remain usable.
struct WorkspaceExplorerArchiveNotice: View {
    let availability: WorkspaceExplorerArchiveAvailability
    let onRetry: () -> Void

    var body: some View {
        if availability != .available {
            HStack(spacing: 8) {
                Text(message)
                Spacer()
                if availability == .unavailable {
                    Button(String(localized: "explorer.retry", defaultValue: "Retry"), action: onRetry)
                }
            }
            .font(.system(size: 12))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var message: String {
        switch availability {
        case .pending:
            String(localized: "explorer.historyLoading", defaultValue:
                "Loading retained history… Past workspaces are not counted until the query completes.")
        case .unavailable:
            String(localized: "explorer.historyUnavailable", defaultValue:
                "Some history could not be loaded. Past workspace counts may be incomplete.")
        case .available:
            ""
        }
    }
}
