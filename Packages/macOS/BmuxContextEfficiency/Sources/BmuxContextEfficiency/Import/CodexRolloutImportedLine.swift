import Foundation

struct CodexRolloutImportedLine: Equatable, Sendable {
    var text: String
    var sourceReference: ContextEfficiencySourceReference
    var parserErrorMessage: String? = nil
}
