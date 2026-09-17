import Foundation

/// Delivery belongs to the connection owner, never to a mounted Chat view.
public struct CodexControlAction: Sendable, Equatable, Codable, Identifiable {
    public enum Operation: String, Sendable, Codable { case queue, steer }
    public enum Delivery: String, Sendable, Codable {
        case pending, accepted, failed, uncertain
    }
    public let id: UUID
    public let threadID: String
    public let operation: Operation
    public let expectedTurnID: String?
    public let text: String
    public internal(set) var delivery: Delivery
    public internal(set) var providerID: String?

    public init(id: UUID, threadID: String, operation: Operation, expectedTurnID: String? = nil, text: String) {
        self.id = id
        self.threadID = threadID
        self.operation = operation
        self.expectedTurnID = expectedTurnID
        self.text = text
        delivery = .pending
    }
}
