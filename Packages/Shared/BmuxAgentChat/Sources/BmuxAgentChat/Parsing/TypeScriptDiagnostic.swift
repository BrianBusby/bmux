import Foundation

struct TypeScriptDiagnostic: Sendable {
    let file: String
    let location: String
    let code: String
    let message: String

    init?(line: String) {
        guard let match = line.firstMatch(
            of: /^(.+?)\((\d+,\d+)\):\s+error\s+(TS\d+):\s+(.+)$/
        ) else {
            return nil
        }
        file = String(match.1)
        location = String(match.2)
        code = String(match.3)
        message = String(match.4)
    }
}
