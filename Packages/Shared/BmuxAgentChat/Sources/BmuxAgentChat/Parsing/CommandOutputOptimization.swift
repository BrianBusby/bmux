import Foundation

struct CommandOutputOptimization: Sendable {
    let kind: CommandOutputKind
    let text: String
    let wasOptimized: Bool
    let omittedLineCount: Int

    init(
        kind: CommandOutputKind,
        text: String,
        wasOptimized: Bool,
        omittedLineCount: Int = 0
    ) {
        self.kind = kind
        self.text = text
        self.wasOptimized = wasOptimized
        self.omittedLineCount = omittedLineCount
    }
}
