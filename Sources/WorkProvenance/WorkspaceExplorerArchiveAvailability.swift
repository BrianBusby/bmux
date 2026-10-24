import Foundation

enum WorkspaceExplorerArchiveAvailability: Equatable {
    case pending
    case available
    case unavailable

    var closedCountLabel: String? {
        switch self {
        case .pending:
            String(localized: "explorer.count.closedPending", defaultValue: "closed pending")
        case .available:
            nil
        case .unavailable:
            String(localized: "explorer.count.closedUnknown", defaultValue: "closed unknown")
        }
    }
}
