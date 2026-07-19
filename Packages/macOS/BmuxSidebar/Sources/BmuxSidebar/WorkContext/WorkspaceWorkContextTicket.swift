public import Foundation

/// A ticket or issue key associated with workspace work context.
public struct WorkspaceWorkContextTicket: Equatable, Sendable {
    /// The complete ticket key, such as `STE-1234`.
    public let key: String

    /// The numeric ticket component, when known.
    public let number: Int?

    /// The ticket URL, when known.
    public let url: URL?

    /// Where this ticket value came from.
    public let source: WorkspaceWorkContextSource

    /// Whether the ticket value may no longer match the active work.
    public let isStale: Bool

    /// Creates a ticket context.
    /// - Parameters:
    ///   - key: The complete ticket key, such as `STE-1234`.
    ///   - number: The numeric ticket component, when known.
    ///   - url: The ticket URL, when known.
    ///   - source: Where this ticket value came from.
    ///   - isStale: Whether the value may no longer match the active work.
    public init(
        key: String,
        number: Int?,
        url: URL?,
        source: WorkspaceWorkContextSource,
        isStale: Bool = false
    ) {
        self.key = key
        self.number = number
        self.url = url
        self.source = source
        self.isStale = isStale
    }

    /// Creates a ticket context by parsing a ticket key from a branch name.
    /// - Parameters:
    ///   - branchName: The branch name that may contain a ticket key.
    ///   - source: Where the parsed ticket value came from.
    ///   - isStale: Whether the value may no longer match the active work.
    public init?(
        branchName: String,
        source: WorkspaceWorkContextSource = .branchName,
        isStale: Bool = false
    ) {
        guard let (projectKey, numberString) = Self.branchTicketComponents(in: branchName),
              let number = Int(numberString) else {
            return nil
        }
        let key = "\(projectKey.uppercased())-\(numberString)"
        self.init(
            key: key,
            number: number,
            url: nil,
            source: source,
            isStale: isStale
        )
    }

    private static func branchTicketComponents(in branchName: String) -> (projectKey: String, number: String)? {
        let pattern = #"(^|[^A-Za-z0-9])([A-Za-z][A-Za-z0-9]{1,5})[-_/]([0-9]{1,9})(?=$|[^A-Za-z0-9])"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let source = branchName as NSString
        let range = NSRange(location: 0, length: source.length)
        guard let match = expression.firstMatch(in: branchName, range: range),
              match.range(at: 2).location != NSNotFound,
              match.range(at: 3).location != NSNotFound else {
            return nil
        }
        return (
            source.substring(with: match.range(at: 2)),
            source.substring(with: match.range(at: 3))
        )
    }
}
