import Foundation

struct CLIProvenanceExplanationRow: Equatable {
    let fileStatus: String?
    let attributionSource: String?
    let attributionConfidence: String?
    let updatedAt: Double?
    let changeSet: [String: AnyHashable]?
    let checkpoint: [String: AnyHashable]?
    let contribution: [String: AnyHashable]?
    let session: [String: AnyHashable]?
    let workItem: [String: AnyHashable]?
    let worktree: [String: AnyHashable]
    let repository: [String: AnyHashable]
}
