import Foundation

/// REST payload returned by the sidecar bounded execution telemetry event endpoint.
public struct ExecutionTelemetryEventReadPayload: Sendable, Equatable, Decodable {
    /// bmux sidecar session id requested by the caller.
    public let sessionID: String

    /// Latest retained canonical telemetry sequence for the session.
    public let latestSequence: Int

    /// Canonical telemetry envelopes after the requested sequence cursor.
    public let events: [ExecutionTelemetryEventEnvelope]

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case latestSequence
        case events
    }
}

/// One sidecar-assigned canonical execution telemetry envelope.
public struct ExecutionTelemetryEventEnvelope: Sendable, Equatable, Decodable {
    public let schema: String
    public let eventID: String
    public let sessionID: String
    public let sequence: Int
    public let capturedAtMs: Int
    public let source: String
    public let provider: String
    public let providerSessionID: String?
    public let providerTurnID: String?
    public let providerEvent: ExecutionTelemetryProviderEventRef?
    public let event: ExecutionTelemetryEvent

    private enum CodingKeys: String, CodingKey {
        case schema
        case eventID = "eventId"
        case sessionID = "sessionId"
        case sequence
        case capturedAtMs
        case source
        case provider
        case providerSessionID = "providerSessionId"
        case providerTurnID = "providerTurnId"
        case providerEvent
        case event
    }
}

/// Provider-side identity fields preserved on a canonical telemetry envelope.
public struct ExecutionTelemetryProviderEventRef: Sendable, Equatable, Decodable {
    public let method: String?
    public let requestID: String?
    public let itemID: String?
    public let turnID: String?
    public let sequence: String?

    private enum CodingKeys: String, CodingKey {
        case method
        case requestID = "requestId"
        case itemID = "itemId"
        case turnID = "turnId"
        case sequence
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.method = try container.decodeLooseStringIfPresent(forKey: .method)
        self.requestID = try container.decodeLooseStringIfPresent(forKey: .requestID)
        self.itemID = try container.decodeLooseStringIfPresent(forKey: .itemID)
        self.turnID = try container.decodeLooseStringIfPresent(forKey: .turnID)
        self.sequence = try container.decodeLooseStringIfPresent(forKey: .sequence)
    }
}

/// Canonical execution telemetry event shapes consumed by native producers.
public enum ExecutionTelemetryEvent: Sendable, Equatable, Decodable {
    case sessionStarted(ExecutionTelemetrySessionStartedEvent)
    case providerSessionLinked(ExecutionTelemetryProviderSessionLinkedEvent)
    case promptSubmitted(ExecutionTelemetryPromptSubmittedEvent)
    case turnStarted(ExecutionTelemetryTurnStartedEvent)
    case turnCompleted(ExecutionTelemetryTurnCompletedEvent)
    case turnFailed(ExecutionTelemetryTurnFailedEvent)
    case planUpdated(ExecutionTelemetryPlanUpdatedEvent)
    case messageCompleted(ExecutionTelemetryMessageCompletedEvent)
    case toolStarted(ExecutionTelemetryToolStartedEvent)
    case toolCompleted(ExecutionTelemetryToolCompletedEvent)
    case filesChanged(ExecutionTelemetryFilesChangedEvent)
    case unsupported(type: String)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "session.started":
            self = .sessionStarted(try ExecutionTelemetrySessionStartedEvent(from: decoder))
        case "session.provider-linked":
            self = .providerSessionLinked(try ExecutionTelemetryProviderSessionLinkedEvent(from: decoder))
        case "prompt.submitted":
            self = .promptSubmitted(try ExecutionTelemetryPromptSubmittedEvent(from: decoder))
        case "turn.started":
            self = .turnStarted(try ExecutionTelemetryTurnStartedEvent(from: decoder))
        case "turn.completed":
            self = .turnCompleted(try ExecutionTelemetryTurnCompletedEvent(from: decoder))
        case "turn.failed":
            self = .turnFailed(try ExecutionTelemetryTurnFailedEvent(from: decoder))
        case "plan.updated":
            self = .planUpdated(try ExecutionTelemetryPlanUpdatedEvent(from: decoder))
        case "message.completed":
            self = .messageCompleted(try ExecutionTelemetryMessageCompletedEvent(from: decoder))
        case "tool.started":
            self = .toolStarted(try ExecutionTelemetryToolStartedEvent(from: decoder))
        case "tool.completed":
            self = .toolCompleted(try ExecutionTelemetryToolCompletedEvent(from: decoder))
        case "files.changed":
            self = .filesChanged(try ExecutionTelemetryFilesChangedEvent(from: decoder))
        default:
            self = .unsupported(type: type)
        }
    }
}

public struct ExecutionTelemetrySessionStartedEvent: Sendable, Equatable, Decodable {
    public let cwd: String
    public let title: String?
}

public struct ExecutionTelemetryProviderSessionLinkedEvent: Sendable, Equatable, Decodable {
    public let providerSessionID: String

    private enum CodingKeys: String, CodingKey {
        case providerSessionID = "providerSessionId"
    }
}

public struct ExecutionTelemetryPromptSubmittedEvent: Sendable, Equatable, Decodable {
    public let text: String
}

public struct ExecutionTelemetryTurnStartedEvent: Sendable, Equatable, Decodable {
    public let turnID: String?
    public let model: String?
    public let effort: String?

    private enum CodingKeys: String, CodingKey {
        case turnID = "turnId"
        case model
        case effort
    }
}

public struct ExecutionTelemetryTurnCompletedEvent: Sendable, Equatable, Decodable {
    public let turnID: String?
    public let durationMs: Int?

    private enum CodingKeys: String, CodingKey {
        case turnID = "turnId"
        case durationMs
    }
}

public struct ExecutionTelemetryTurnFailedEvent: Sendable, Equatable, Decodable {
    public let turnID: String?
    public let durationMs: Int?
    public let error: ExecutionTelemetryErrorInfo

    private enum CodingKeys: String, CodingKey {
        case turnID = "turnId"
        case durationMs
        case error
    }
}

public struct ExecutionTelemetryPlanUpdatedEvent: Sendable, Equatable, Decodable {
    public let explanation: String?
    public let steps: [ExecutionTelemetryPlanStep]
}

public struct ExecutionTelemetryPlanStep: Sendable, Equatable, Decodable {
    public let text: String
    public let status: String
}

public struct ExecutionTelemetryMessageCompletedEvent: Sendable, Equatable, Decodable {
    public let stream: String
    public let itemID: String?
    public let text: String?

    private enum CodingKeys: String, CodingKey {
        case stream
        case itemID = "itemId"
        case text
    }
}

public struct ExecutionTelemetryToolStartedEvent: Sendable, Equatable, Decodable {
    public let operationID: String
    public let toolKind: String
    public let name: String
    public let inputSummary: String?
    public let cwd: String?
    public let startedAtMs: Int?

    private enum CodingKeys: String, CodingKey {
        case operationID = "operationId"
        case toolKind
        case name
        case inputSummary
        case cwd
        case startedAtMs
    }
}

public struct ExecutionTelemetryToolCompletedEvent: Sendable, Equatable, Decodable {
    public let operationID: String
    public let toolKind: String?
    public let name: String?
    public let status: String
    public let outputSummary: String?
    public let exitCode: Int?
    public let durationMs: Int?
    public let completedAtMs: Int?

    private enum CodingKeys: String, CodingKey {
        case operationID = "operationId"
        case toolKind
        case name
        case status
        case outputSummary
        case exitCode
        case durationMs
        case completedAtMs
    }
}

public struct ExecutionTelemetryFilesChangedEvent: Sendable, Equatable, Decodable {
    public let source: String
    public let files: [ExecutionTelemetryChangedFile]
}

public struct ExecutionTelemetryChangedFile: Sendable, Equatable, Decodable {
    public let path: String
    public let status: String
    public let additions: Int?
    public let deletions: Int?
    public let summary: String?
}

public struct ExecutionTelemetryErrorInfo: Sendable, Equatable, Decodable {
    public let message: String
    public let code: String?
}

private extension KeyedDecodingContainer {
    func decodeLooseStringIfPresent(forKey key: Key) throws -> String? {
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return string
        }
        if let int = try? decodeIfPresent(Int.self, forKey: key) {
            return String(int)
        }
        if let double = try? decodeIfPresent(Double.self, forKey: key) {
            return String(double)
        }
        return nil
    }
}
