import Foundation

extension ExpandedTurnCommandCategory {
    var title: String {
        switch self {
        case .git: String(localized: "agentSession.expanded.category.git", defaultValue: "Git")
        case .read: String(localized: "agentSession.expanded.category.read", defaultValue: "Read / search")
        case .edit: String(localized: "agentSession.expanded.category.edit", defaultValue: "Edit")
        case .build: String(localized: "agentSession.expanded.category.build", defaultValue: "Build / test")
        case .bmux: String(localized: "agentSession.expanded.category.bmux", defaultValue: "bmux")
        case .other: String(localized: "agentSession.expanded.category.other", defaultValue: "Other")
        }
    }
}
