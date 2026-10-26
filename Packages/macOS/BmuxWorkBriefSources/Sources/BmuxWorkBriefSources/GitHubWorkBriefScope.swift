import Foundation

/// Explicit GitHub organization or repository scope for read-only searches.
public struct GitHubWorkBriefScope: Equatable, Hashable, Sendable {
    /// Search qualifier accepted by GitHub, e.g. `org:CompanyCam`.
    public let qualifier: String

    /// Validates a narrow organization or owner/repository qualifier.
    /// - Parameter raw: An `org:Name` or `repo:Owner/Name` search scope.
    /// - Returns: A validated scope, or `nil` when the qualifier is unsupported.
    public init?(_ raw: String) {
        let parts = raw.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let kind = String(parts[0]).lowercased()
        let value = String(parts[1])
        guard kind == "org" || kind == "repo", !value.isEmpty, value.count <= 100 else { return nil }
        let names = value.split(separator: "/", omittingEmptySubsequences: false)
        guard names.count == (kind == "org" ? 1 : 2),
              names.allSatisfy({ !$0.isEmpty && $0.count <= 50 &&
                  $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == ".") } })
        else { return nil }
        qualifier = "\(kind):\(value)"
    }
}
