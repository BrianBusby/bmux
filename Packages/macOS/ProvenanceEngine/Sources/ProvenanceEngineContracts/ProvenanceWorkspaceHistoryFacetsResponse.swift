import Foundation

/// Metadata needed to offer filters before all workspace-history pages are loaded.
public struct ProvenanceWorkspaceHistoryFacetsResponse: Codable, Equatable, Sendable {
    /// Filter facts for workspaces with retained sessions after the latest history clear.
    public let facets: [ProvenanceWorkspaceHistoryFacet]

    /// Creates a response with retained workspace filter facts.
    /// - Parameter facets: Filter facts for retained workspace identities.
    public init(facets: [ProvenanceWorkspaceHistoryFacet]) {
        self.facets = facets
    }
}
