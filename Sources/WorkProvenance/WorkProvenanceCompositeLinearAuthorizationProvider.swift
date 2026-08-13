/// Tries multiple Linear authorization providers in order.
struct WorkProvenanceCompositeLinearAuthorizationProvider: WorkProvenanceLinearAuthorizationProviding {
    private let providers: [any WorkProvenanceLinearAuthorizationProviding]

    init(_ providers: [any WorkProvenanceLinearAuthorizationProviding]) {
        self.providers = providers
    }

    func authorizationHeader() async -> String? {
        for provider in providers {
            if let header = await provider.authorizationHeader() {
                return header
            }
        }
        return nil
    }
}
