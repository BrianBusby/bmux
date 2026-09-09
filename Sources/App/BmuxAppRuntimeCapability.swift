import Foundation

enum BmuxAppRuntimeCapability: Hashable, Sendable {
    case workProvenanceObservation
    case agentChatExecutionTelemetryProjection
    case mobileHostAndPresence
    case browserAndDevTools
    case sidebarGitPullRequestObservation
}
