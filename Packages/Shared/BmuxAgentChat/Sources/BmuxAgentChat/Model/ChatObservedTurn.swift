/// The latest provider-authored turn lifecycle observed in a transcript.
/// Absence means unknown; no timing or prose heuristic supplies a state.
public struct ChatObservedTurn: Sendable, Equatable, Codable {
    public enum State: String, Sendable, Codable {
        case working, completed, interrupted
    }

    public let id: String
    public let state: State

    public init(id: String, state: State) {
        self.id = id
        self.state = state
    }
}
