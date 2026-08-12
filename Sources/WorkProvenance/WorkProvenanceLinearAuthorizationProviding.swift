/// Supplies a Linear GraphQL Authorization header for ticket-title lookups.
protocol WorkProvenanceLinearAuthorizationProviding: Sendable {
    func authorizationHeader() async -> String?
}
