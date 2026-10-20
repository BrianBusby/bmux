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
