import SwiftUI

struct SessionTranscriptTurn: Identifiable, Equatable, Sendable {
    let id: Int
    let role: SessionTranscriptRole
    let text: String
    let timestamp: Date?
    let finishedAt: Date?

    init(
        id: Int,
        role: SessionTranscriptRole,
        text: String,
        timestamp: Date? = nil,
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.finishedAt = finishedAt ?? timestamp
    }
}

enum SessionTranscriptRole: Equatable, Sendable {
    case user
    case assistant
    case system
    case tool
    case event

    var label: String {
        switch self {
        case .user:
            return String(localized: "sessionIndex.preview.role.user", defaultValue: "You")
        case .assistant:
            return String(localized: "sessionIndex.preview.role.assistant", defaultValue: "Agent")
        case .system:
            return String(localized: "sessionIndex.preview.role.system", defaultValue: "System")
        case .tool:
            return String(localized: "sessionIndex.preview.role.tool", defaultValue: "Tool")
        case .event:
            return String(localized: "sessionIndex.preview.role.event", defaultValue: "Event")
        }
    }

    var foregroundColor: Color {
        switch self {
        case .user: return .accentColor
        case .assistant: return .green
        case .system: return .secondary
        case .tool: return .orange
        case .event: return .secondary
        }
    }

    func foregroundColor(colorScheme: ColorScheme) -> Color {
        switch self {
        case .user:
            return colorScheme == .dark ? .black : .white
        case .assistant, .system, .tool, .event:
            return foregroundColor
        }
    }

    var backgroundColor: Color {
        switch self {
        case .user: return Color.accentColor.opacity(0.035)
        case .assistant: return Color.green.opacity(0.035)
        case .system: return Color.primary.opacity(0.025)
        case .tool: return Color.orange.opacity(0.035)
        case .event: return Color.primary.opacity(0.02)
        }
    }

    func backgroundColor(colorScheme: ColorScheme) -> Color {
        switch self {
        case .user:
            return colorScheme == .dark ? .white : .black
        case .assistant, .system, .tool, .event:
            return backgroundColor
        }
    }

    func bodyForegroundColor(colorScheme: ColorScheme) -> Color {
        switch self {
        case .user:
            return foregroundColor(colorScheme: colorScheme)
        case .assistant, .system, .tool, .event:
            return .primary.opacity(0.92)
        }
    }

    var bodyFontSize: CGFloat {
        switch self {
        case .tool, .system:
            return 11
        case .user, .assistant, .event:
            return 12
        }
    }

    var bodyFontDesign: Font.Design {
        switch self {
        case .tool, .system:
            return .monospaced
        case .user, .assistant, .event:
            return .default
        }
    }
}
