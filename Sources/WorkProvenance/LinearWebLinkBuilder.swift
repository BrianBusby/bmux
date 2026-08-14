import Foundation

/// Builds Linear web URLs from workspace-relative identifiers.
struct LinearWebLinkBuilder: Equatable, Sendable {
    private static let defaultWorkspaceSlug = "companycam"
    private static let issuePattern = #"^[A-Z][A-Z0-9]+-[0-9]+$"#
    private static let workspaceSlugPattern = #"^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$"#
    private static let pathComponentAllowedCharacters: CharacterSet = {
        var characters = CharacterSet.urlPathAllowed
        characters.remove(charactersIn: "/?#")
        return characters
    }()

    private let workspaceSlug: String

    init(workspaceSlug: String = Self.defaultWorkspaceSlug) {
        self.workspaceSlug = Self.normalizedWorkspaceSlug(workspaceSlug) ?? Self.defaultWorkspaceSlug
    }

    func issueURLString(apiURL: String?, ticketID: String) -> String? {
        normalizedURLString(apiURL) ?? issueURLString(for: ticketID)
    }

    func issueURLString(for ticketID: String) -> String? {
        guard let normalizedTicketID = Self.normalizedIssueIdentifier(ticketID) else {
            return nil
        }
        return "https://linear.app/\(workspaceSlug)/issue/\(normalizedTicketID)"
    }

    func issueURL(for ticketID: String) -> URL? {
        issueURLString(for: ticketID).flatMap(URL.init(string:))
    }

    func projectURLString(forProjectSlug projectSlug: String) -> String? {
        guard let normalizedProjectSlug = Self.normalizedPathComponent(projectSlug) else {
            return nil
        }
        return "https://linear.app/\(workspaceSlug)/project/\(normalizedProjectSlug)"
    }

    func projectURL(forProjectSlug projectSlug: String) -> URL? {
        projectURLString(forProjectSlug: projectSlug).flatMap(URL.init(string:))
    }

    private func normalizedURLString(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              let components = URLComponents(string: value),
              components.scheme == "https",
              components.host == "linear.app" else {
            return nil
        }
        return value
    }

    private static func normalizedWorkspaceSlug(_ value: String) -> String? {
        let slug = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard slug.range(of: workspaceSlugPattern, options: .regularExpression) != nil else {
            return nil
        }
        return slug
    }

    private static func normalizedIssueIdentifier(_ value: String) -> String? {
        let identifier = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard identifier.range(of: issuePattern, options: .regularExpression) != nil else {
            return nil
        }
        return identifier
    }

    private static func normalizedPathComponent(_ value: String) -> String? {
        let component = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !component.isEmpty else { return nil }
        return component.addingPercentEncoding(withAllowedCharacters: pathComponentAllowedCharacters)
    }
}
