import Foundation

enum WorkspaceExplorerArchiveAvailability: Equatable {
    case pending
    case available
    case unavailable

    var closedCountLabel: String? {
        switch self {
        case .pending:
            String(localized: "explorer.count.pastPending", defaultValue: "past history loading")
        case .available:
            nil
        case .unavailable:
            String(localized: "explorer.count.pastUnknown", defaultValue: "past history incomplete")
        }
    }
}
