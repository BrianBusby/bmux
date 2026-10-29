import Foundation

enum AgentSessionFactualProjectionMode: String, CaseIterable, Identifiable {
    case chat
    case turn
    case terminal
    case session

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terminal:
            String(localized: "agentSession.viewMode.terminal", defaultValue: "Terminal")
        case .chat:
            String(localized: "agentSession.viewMode.chat", defaultValue: "Chat")
        case .turn:
            String(localized: "agentSession.viewMode.turn", defaultValue: "Turn")
        case .session:
            String(localized: "agentSession.viewMode.session", defaultValue: "Session")
        }
    }
}
