import BmuxFoundation
import BmuxGit
import BmuxSidebarGit
import Foundation

@MainActor
struct SidebarGitPullRequestObservationHostServices {
    let sidebarGitMetadataService: any SidebarGitMetadataServing
    let pullRequestProbing: any PullRequestProbing
}

@MainActor
struct SidebarGitPullRequestObservationRuntimeServiceDependencies {
    var validateRequiredRuntime: () -> SidebarGitPullRequestObservationRuntimeOperationResult
    var makeHostServices: () -> SidebarGitPullRequestObservationHostServices
    var promptMentionProbeService: PullRequestProbeService

    static func production() -> SidebarGitPullRequestObservationRuntimeServiceDependencies {
#if DEBUG
        let sidebarGitDebugLog: @Sendable (String) -> Void = { bmuxDebugLog($0) }
#else
        let sidebarGitDebugLog: @Sendable (String) -> Void = { _ in }
#endif
        let commandRunner = CommandRunner()
        let gitMetadataService = GitMetadataService()
        let pullRequestProbeService = PullRequestProbeService(
            commandRunner: commandRunner,
            debugLog: sidebarGitDebugLog
        )
        let gitPollClock = SystemGitPollClock()
        let probeLimiter = WorkspaceGitMetadataProbeLimiter(limit: 2)

        return SidebarGitPullRequestObservationRuntimeServiceDependencies(
            validateRequiredRuntime: { .ready },
            makeHostServices: {
                let pullRequestPollService = PullRequestPollService(
                    gitMetadataService: gitMetadataService,
                    probeService: pullRequestProbeService,
                    clock: gitPollClock,
                    mobileHostDeferral: .standard,
                    debugLog: sidebarGitDebugLog
                )
                let sidebarGitMetadataService = SidebarGitMetadataService(
                    workspaceGitMetadataReader: gitMetadataService,
                    gitMetadataService: gitMetadataService,
                    pullRequestProbing: pullRequestPollService,
                    probeLimiter: probeLimiter,
                    clock: gitPollClock,
                    mobileHostDeferral: .standard,
                    debugLog: sidebarGitDebugLog
                )
                return SidebarGitPullRequestObservationHostServices(
                    sidebarGitMetadataService: sidebarGitMetadataService,
                    pullRequestProbing: pullRequestPollService
                )
            },
            promptMentionProbeService: pullRequestProbeService
        )
    }
}
