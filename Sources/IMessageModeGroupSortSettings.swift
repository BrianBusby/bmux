import Foundation

/// Per-workspace-group behavior knobs for sidebar iMessage mode.
///
/// - `sortInsideGroups` (default true): when iMessage mode floats workspaces
///   by latest unread, members within a group sort by unread while the group
///   section position stays put.
/// - `floatGroups` (default false): when true, the group section itself
///   reorders by its most-recent unread member.
///
/// Both knobs are persisted to UserDefaults via the keys below and mirrored
/// in `~/.config/bmux/bmux.json` under `sidebar.imessageMode.*`. The sort
/// path treats the current build as passthrough until the broader iMessage
/// sort logic exists; the knobs land here so user-set values survive the
/// upgrade that activates the behavior.
enum IMessageModeGroupSortSettings {
    static let sortInsideGroupsKey = "app.iMessageMode.sortInsideGroups"
    static let floatGroupsKey = "app.iMessageMode.floatGroups"
    static let sortInsideGroupsDefault = true
    static let floatGroupsDefault = false

    static func sortInsideGroups(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: sortInsideGroupsKey) == nil {
            return sortInsideGroupsDefault
        }
        return defaults.bool(forKey: sortInsideGroupsKey)
    }

    static func floatGroups(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: floatGroupsKey) == nil {
            return floatGroupsDefault
        }
        return defaults.bool(forKey: floatGroupsKey)
    }

    static func setSortInsideGroups(_ value: Bool, defaults: UserDefaults = .standard) {
        if value == sortInsideGroupsDefault {
            defaults.removeObject(forKey: sortInsideGroupsKey)
        } else {
            defaults.set(value, forKey: sortInsideGroupsKey)
        }
    }

    static func setFloatGroups(_ value: Bool, defaults: UserDefaults = .standard) {
        if value == floatGroupsDefault {
            defaults.removeObject(forKey: floatGroupsKey)
        } else {
            defaults.set(value, forKey: floatGroupsKey)
        }
    }
}
