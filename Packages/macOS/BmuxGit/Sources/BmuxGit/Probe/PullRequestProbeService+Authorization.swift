import Foundation

extension PullRequestProbeService {
    /// Returns the existing GitHub credential for another read-only GitHub client.
    /// The caller must keep the returned header out of logs and persisted state.
    public nonisolated func authorizationHeaderForReadOnlyAPI() async -> String? {
        await authHeaderValue()
    }
}
