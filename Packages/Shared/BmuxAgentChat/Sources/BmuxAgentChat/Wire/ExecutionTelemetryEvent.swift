/// Canonical execution telemetry event shapes consumed by native producers.
public enum ExecutionTelemetryEvent: Sendable, Equatable, Decodable {
    /// The sidecar observed a session start.
    case sessionStarted(ExecutionTelemetrySessionStartedEvent)

    /// The provider linked its native session/thread identity.
    case providerSessionLinked(ExecutionTelemetryProviderSessionLinkedEvent)

    /// The user submitted prompt text for a turn.
    case promptSubmitted(ExecutionTelemetryPromptSubmittedEvent)

    /// The provider reported turn start metadata.
    case turnStarted(ExecutionTelemetryTurnStartedEvent)

    /// The provider reported successful turn completion.
    case turnCompleted(ExecutionTelemetryTurnCompletedEvent)

    /// The provider reported turn failure.
    case turnFailed(ExecutionTelemetryTurnFailedEvent)

    /// The provider emitted a plan update.
    case planUpdated(ExecutionTelemetryPlanUpdatedEvent)

    /// The provider completed a message item.
    case messageCompleted(ExecutionTelemetryMessageCompletedEvent)

    /// The provider started a tool operation.
    case toolStarted(ExecutionTelemetryToolStartedEvent)

    /// The provider completed a tool operation.
    case toolCompleted(ExecutionTelemetryToolCompletedEvent)

    /// The sidecar observed file changes for a turn.
    case filesChanged(ExecutionTelemetryFilesChangedEvent)

    /// Event type this client does not understand yet.
    case unsupported(type: String)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    /// Creates a canonical event from its wire discriminator.
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
