import Foundation

enum WorkspaceExplorerReopenReason: Equatable {
    case historyLoading
    case noRestoreSnapshot
    case noDirectoryRecorded
    case directoryRemoved
    case noRestorablePanels
    case alreadyOpen
    case unsupportedRemoteRestore
}

extension WorkspaceExplorerReopenReason {
    var localizedDescription: String {
        switch self {
        case .historyLoading:
            String(localized: "explorer.reopen.historyLoading", defaultValue: "History is still loading.")
        case .noRestoreSnapshot:
            String(localized: "explorer.reopen.noRestoreSnapshot", defaultValue: "No restoration snapshot is available.")
        case .noDirectoryRecorded:
            String(localized: "explorer.reopen.noDirectoryRecorded", defaultValue: "No local directory was recorded.")
        case .directoryRemoved:
            String(localized: "explorer.reopen.directoryRemoved", defaultValue: "The recorded directory no longer exists.")
        case .noRestorablePanels:
            String(localized: "explorer.reopen.noRestorablePanels", defaultValue: "No restorable panels were recorded.")
        case .alreadyOpen:
            String(localized: "explorer.reopen.alreadyOpen", defaultValue: "This workspace is already open.")
        case .unsupportedRemoteRestore:
            String(localized: "explorer.reopen.unsupportedRemoteRestore", defaultValue: "Remote restoration is not supported here.")
        }
    }
}
