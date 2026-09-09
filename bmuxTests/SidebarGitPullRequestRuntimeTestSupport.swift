import BmuxFoundation
import BmuxGit
import BmuxSidebar
import BmuxSidebarGit
import Foundation

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

struct RecordedInitialGitRefresh: Equatable {
    let workspaceId: UUID
    let panelId: UUID
    let reason: String
}

@MainActor
final class SidebarGitPullRequestRuntimeTestHarness {
    var validateRequiredRuntimeResult: SidebarGitPullRequestObservationRuntimeOperationResult
    var validateRequiredRuntimeCount = 0
    var makeHostServicesCount = 0
    var services: [RecordingSidebarGitPullRequestObservationService] = []
    private let publishObservedFactsOnInitialRefresh: Bool
    private let shouldFailWorkspace: (UUID) -> Bool
    private let promptMentionCommandRunner: any CommandRunning

    init(
        validateRequiredRuntimeResult: SidebarGitPullRequestObservationRuntimeOperationResult = .ready,
        publishObservedFactsOnInitialRefresh: Bool = false,
        shouldFailWorkspace: @escaping (UUID) -> Bool = { _ in false },
        promptMentionCommandRunner: any CommandRunning = NoopCommandRunner()
    ) {
        self.validateRequiredRuntimeResult = validateRequiredRuntimeResult
        self.publishObservedFactsOnInitialRefresh = publishObservedFactsOnInitialRefresh
        self.shouldFailWorkspace = shouldFailWorkspace
        self.promptMentionCommandRunner = promptMentionCommandRunner
    }

    func dependencies() -> SidebarGitPullRequestObservationRuntimeServiceDependencies {
        SidebarGitPullRequestObservationRuntimeServiceDependencies(
            validateRequiredRuntime: {
                self.validateRequiredRuntimeCount += 1
                return self.validateRequiredRuntimeResult
            },
            makeHostServices: {
                self.makeHostServicesCount += 1
                let service = RecordingSidebarGitPullRequestObservationService(
                    publishObservedFactsOnInitialRefresh: self.publishObservedFactsOnInitialRefresh,
                    shouldFailWorkspace: self.shouldFailWorkspace
                )
                self.services.append(service)
                return SidebarGitPullRequestObservationHostServices(
                    sidebarGitMetadataService: service,
                    pullRequestProbing: service
                )
            },
            promptMentionProbeService: PullRequestProbeService(
                commandRunner: promptMentionCommandRunner,
                debugLog: { _ in }
            )
        )
    }
}

@MainActor
final class RecordingSidebarGitPullRequestObservationService: SidebarGitMetadataServing, PullRequestProbing {
    private weak var host: (any SidebarGitHosting)?
    private let publishObservedFactsOnInitialRefresh: Bool
    private let shouldFailWorkspace: (UUID) -> Bool
    var attachCount = 0
    var initialGitRefreshes: [RecordedInitialGitRefresh] = []
    var pullRequestRefreshReasons: [String] = []
    var scheduledPullRequestRefreshes: [RecordedInitialGitRefresh] = []
    var clearedGitWorkspaceIds: [UUID] = []
    var clearedPullRequestWorkspaceIds: [UUID] = []
    var stopSidebarGitObservationCount = 0
    var stopPullRequestObservationCount = 0
    private var trackedPullRequestPanelIdsByWorkspaceId: [UUID: Set<UUID>] = [:]

    init(
        publishObservedFactsOnInitialRefresh: Bool,
        shouldFailWorkspace: @escaping (UUID) -> Bool
    ) {
        self.publishObservedFactsOnInitialRefresh = publishObservedFactsOnInitialRefresh
        self.shouldFailWorkspace = shouldFailWorkspace
    }

    func attach(host: any SidebarGitHosting) {
        attachCount += 1
        self.host = host
    }

    func scheduleInitialWorkspaceGitMetadataRefreshIfPossible(workspaceId: UUID, panelId: UUID, reason: String) {
        initialGitRefreshes.append(RecordedInitialGitRefresh(workspaceId: workspaceId, panelId: panelId, reason: reason))
        guard publishObservedFactsOnInitialRefresh, !shouldFailWorkspace(workspaceId), let host else { return }
        host.updatePanelGitBranch(
            workspaceId: workspaceId,
            panelId: panelId,
            branch: "feature/pr-5314-runtime",
            isDirty: true
        )
        host.updatePanelPullRequest(
            workspaceId: workspaceId,
            panelId: panelId,
            badge: SidebarPullRequestBadge(
                number: 5314,
                title: "Runtime migration",
                label: "PR",
                url: URL(string: "https://github.com/manaflow-ai/bmux/pull/5314")!,
                ownerLogin: "octocat",
                ownerURL: URL(string: "https://github.com/octocat"),
                status: .open,
                branch: "feature/pr-5314-runtime",
                isStale: false
            )
        )
        trackedPullRequestPanelIdsByWorkspaceId[workspaceId, default: []].insert(panelId)
    }

    func updateSurfaceDirectory(workspaceId: UUID, panelId: UUID, directory: String, displayLabel: String?) {
        _ = host?.updatePanelDirectory(workspaceId: workspaceId, panelId: panelId, directory: directory, displayLabel: displayLabel)
    }

    func updateRemoteSurfaceDirectory(workspaceId: UUID, panelId: UUID, directory: String, displayLabel: String?) {
        _ = host?.updateRemotePanelDirectory(workspaceId: workspaceId, panelId: panelId, directory: directory, displayLabel: displayLabel)
    }

    func updateSurfaceGitBranch(workspaceId: UUID, panelId: UUID, branch: String, isDirty: Bool?) {
        host?.updatePanelGitBranch(workspaceId: workspaceId, panelId: panelId, branch: branch, isDirty: isDirty ?? false)
    }

    func clearSurfaceGitBranch(workspaceId: UUID, panelId: UUID) {
        host?.clearPanelGitBranch(workspaceId: workspaceId, panelId: panelId)
    }

    func refreshTrackedWorkspaceGitMetadata(reason: String) {}

    func sidebarGitMetadataWatchSettingsDidChange() {}

    func stopSidebarGitMetadataObservation() {
        stopSidebarGitObservationCount += 1
        host = nil
    }

    func clearWorkspaceGitProbes(workspaceId: UUID) {
        clearedGitWorkspaceIds.append(workspaceId)
    }

    func resetAllWorkspaceGitProbeTracking() {
        clearedGitWorkspaceIds.removeAll()
        trackedPullRequestPanelIdsByWorkspaceId.removeAll()
    }

    func trackedWorkspaceGitMetadataPollCandidatePanelIds(workspaceId: UUID) -> Set<UUID> { [] }

    func activeWorkspaceGitProbePanelIds(workspaceId: UUID) -> Set<UUID> { [] }

    func scheduleWorkspacePullRequestRefresh(workspaceId: UUID, panelId: UUID, reason: String) {
        scheduledPullRequestRefreshes.append(RecordedInitialGitRefresh(workspaceId: workspaceId, panelId: panelId, reason: reason))
        trackedPullRequestPanelIdsByWorkspaceId[workspaceId, default: []].insert(panelId)
    }

    func refreshTrackedWorkspacePullRequestsIfNeeded(reason: String) {
        pullRequestRefreshReasons.append(reason)
    }

    func sidebarPullRequestPollingSettingsDidChange() {}

    func stopWorkspacePullRequestObservation() {
        stopPullRequestObservationCount += 1
        host = nil
    }

    func handleWorkspacePullRequestCommandHint(workspaceId: UUID, panelId: UUID, action: String, target: String?) {}

    func clearWorkspacePullRequestTracking(workspaceId: UUID, panelId: UUID) {
        trackedPullRequestPanelIdsByWorkspaceId[workspaceId]?.remove(panelId)
    }

    func clearWorkspacePullRequestMetadata(workspaceId: UUID, panelId: UUID) {
        host?.clearPanelPullRequest(workspaceId: workspaceId, panelId: panelId)
        trackedPullRequestPanelIdsByWorkspaceId[workspaceId]?.remove(panelId)
    }

    func clearWorkspacePullRequestTracking(workspaceId: UUID) {
        clearedPullRequestWorkspaceIds.append(workspaceId)
        trackedPullRequestPanelIdsByWorkspaceId.removeValue(forKey: workspaceId)
    }

    func resetWorkspacePullRequestRefreshState() {
        trackedPullRequestPanelIdsByWorkspaceId.removeAll()
    }

    func workspacePullRequestTrackedPanelIds(workspaceId: UUID) -> Set<UUID> {
        trackedPullRequestPanelIdsByWorkspaceId[workspaceId] ?? []
    }
}

final class SidebarGitPullRequestRuntimeFailureSet: @unchecked Sendable {
    // The harness predicate is synchronous.
    private let lock = NSLock()
    private var workspaceIds: Set<UUID> = []

    func insert(_ workspaceId: UUID) {
        lock.lock()
        workspaceIds.insert(workspaceId)
        lock.unlock()
    }

    func contains(_ workspaceId: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return workspaceIds.contains(workspaceId)
    }
}

struct NoopCommandRunner: CommandRunning {
    func run(directory: String, executable: String, arguments: [String], timeout: TimeInterval?) async -> CommandResult {
        CommandResult(stdout: nil, stderr: "disabled", exitStatus: 127, timedOut: false, executionError: nil)
    }
}

// Mutable command-runner state is fully actor-isolated behind PromptMentionCommandRunnerState.
final class PromptMentionCommandRunner: CommandRunning, @unchecked Sendable {
    private let state = PromptMentionCommandRunnerState()

    func run(directory: String, executable: String, arguments: [String], timeout: TimeInterval?) async -> CommandResult {
        let url = arguments.dropFirst(2).first ?? ""
        return await state.waitForRelease(url: url)
    }

    func waitForRequest(url: String, invocation: Int) async {
        await state.waitForRequest(url: url, invocation: invocation)
    }

    func release(url: String, invocation: Int, result: CommandResult) async {
        await state.release(url: url, invocation: invocation, result: result)
    }
}

private actor PromptMentionCommandRunnerState {
    private struct RequestKey: Hashable {
        let url: String
        let invocation: Int
    }

    private var invocationCountsByURL: [String: Int] = [:]
    private var seenRequests: Set<RequestKey> = []
    private var requestWaiters: [RequestKey: [CheckedContinuation<Void, Never>]] = [:]
    private var pendingResults: [RequestKey: CheckedContinuation<CommandResult, Never>] = [:]
    private var releasedResults: [RequestKey: CommandResult] = [:]

    func waitForRelease(url: String) async -> CommandResult {
        let invocation = (invocationCountsByURL[url] ?? 0) + 1
        invocationCountsByURL[url] = invocation
        let key = RequestKey(url: url, invocation: invocation)
        seenRequests.insert(key)
        if let waiters = requestWaiters.removeValue(forKey: key) {
            for waiter in waiters {
                waiter.resume()
            }
        }
        if let result = releasedResults.removeValue(forKey: key) {
            return result
        }
        return await withCheckedContinuation { continuation in
            pendingResults[key] = continuation
        }
    }

    func waitForRequest(url: String, invocation: Int) async {
        let key = RequestKey(url: url, invocation: invocation)
        guard !seenRequests.contains(key) else { return }
        await withCheckedContinuation { continuation in
            requestWaiters[key, default: []].append(continuation)
        }
    }

    func release(url: String, invocation: Int, result: CommandResult) {
        let key = RequestKey(url: url, invocation: invocation)
        if let continuation = pendingResults.removeValue(forKey: key) {
            continuation.resume(returning: result)
        } else {
            releasedResults[key] = result
        }
    }
}

extension CommandResult {
    static func successJSON(_ stdout: String) -> CommandResult {
        CommandResult(stdout: stdout, stderr: "", exitStatus: 0, timedOut: false, executionError: nil)
    }
}
