import Foundation

/// Identity facts preserved by bmux's restore snapshots after a close.
struct WorkspaceArchiveRecoveryCandidate: Sendable {
    let stableID: UUID
    let title: String
    let closedAt: Date
    let colorHex: String?

    static func latest(_ candidates: [Self]) -> [Self] {
        var latest: [UUID: Self] = [:]
        for candidate in candidates where latest[candidate.stableID]
            .map({ $0.closedAt <= candidate.closedAt }) ?? true {
            latest[candidate.stableID] = candidate
        }
        return latest.values.sorted {
            $0.closedAt == $1.closedAt
                ? $0.stableID.uuidString < $1.stableID.uuidString
                : $0.closedAt > $1.closedAt
        }
    }

    static func from(
        records: [ClosedItemHistoryRecord],
        excluding liveIDs: Set<UUID>
    ) -> [Self] {
        var latest: [UUID: Self] = [:]
        for record in records {
            let snapshots: [SessionWorkspaceSnapshot]
            switch record.entry {
            case .workspace(let entry): snapshots = [entry.snapshot]
            case .window(let entry): snapshots = entry.snapshot.tabManager.workspaces
            case .panel: continue
            }
            for snapshot in snapshots {
                guard let stableID = snapshot.stableId, !liveIDs.contains(stableID) else { continue }
                let candidate = Self(stableID: stableID,
                    title: snapshot.customTitle ?? snapshot.processTitle,
                    closedAt: record.closedAt, colorHex: snapshot.customColor)
                if latest[stableID].map({ $0.closedAt > record.closedAt }) != true {
                    latest[stableID] = candidate
                }
            }
        }
        return Self.latest(Array(latest.values))
    }
}
