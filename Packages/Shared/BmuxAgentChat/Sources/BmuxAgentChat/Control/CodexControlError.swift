/// Machine-readable control errors. UI copy is localized by the consumer.
public enum CodexControlError: Error, Sendable, Equatable {
    case disconnected
    case invalidResponse
    case rejected
    case wrongThread
    case duplicateRequest
    case invalidInput
    case unsupported
    case uncertainDelivery
}
