import Foundation
import Testing
@testable import BmuxControlSocket

@MainActor
@Suite("ControlCommandCoordinator sidebar domain")
struct ControlCommandCoordinatorSidebarTests {
    private final class FakeSidebarControlCommandContext: ControlCommandContext {
        struct ScheduledPullRequest: Equatable {
            let target: ControlSidebarPanelMutationTarget
            let number: Int
            let title: String?
            let label: String
            let url: URL
            let ownerLogin: String?
            let ownerURL: URL?
            let statusRawValue: String
            let branch: String?
        }

        nonisolated(unsafe) var scheduledPullRequest: ScheduledPullRequest?

        func controlWindowSummaries() -> [ControlWindowSummary] { [] }
        func controlResolveCurrentWindow(routing: ControlRoutingSelectors) -> ControlCurrentWindowResolution {
            .tabManagerUnavailable
        }
        func controlFocusWindow(id: UUID) -> Bool { false }
        func controlCreateWindowAndActivate() -> UUID? { nil }
        func controlCloseWindow(id: UUID) -> Bool { false }
        func controlAvailableDisplays() -> [ControlDisplayInfo] { [] }
        func controlWindowExists(id: UUID) -> Bool { false }
        func controlMoveWindow(id: UUID, toDisplayMatching query: String) -> String? { nil }
        func controlMoveAllWindows(toDisplayMatching query: String) -> ControlMoveAllWindowsResult? { nil }

        nonisolated func controlSidebarIsValidPullRequestState(_ raw: String) -> Bool {
            ["open", "merged", "closed"].contains(raw)
        }

        nonisolated func controlSidebarSchedulePanelPullRequestUpdate(
            target: ControlSidebarPanelMutationTarget,
            number: Int,
            title: String?,
            label: String,
            url: URL,
            ownerLogin: String?,
            ownerURL: URL?,
            statusRawValue: String,
            branch: String?
        ) {
            scheduledPullRequest = ScheduledPullRequest(
                target: target,
                number: number,
                title: title,
                label: label,
                url: url,
                ownerLogin: ownerLogin,
                ownerURL: ownerURL,
                statusRawValue: statusRawValue,
                branch: branch
            )
        }
    }

    @Test func reportPullRequestPassesTitleMetadata() throws {
        let context = FakeSidebarControlCommandContext()
        let coordinator = ControlCommandCoordinator(context: context)
        let workspaceID = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let panelID = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let reply = coordinator.handleSidebarTelemetryV1(
            command: "report_pr",
            args: """
            #26288 https://github.com/CompanyCam/Company-Cam-API/pull/26288 \
            --state=merged \
            --title="Display PR titles in sidebar rows" \
            --owner=BrianBusby \
            --branch="fix/sidebar-pr-title" \
            --tab=\(workspaceID.uuidString) \
            --panel=\(panelID.uuidString)
            """,
            context: context
        )

        #expect(reply == "OK")
        let pullRequest = try #require(context.scheduledPullRequest)
        #expect(pullRequest.target.scope == ControlSidebarPanelScope(workspaceID: workspaceID, panelID: panelID))
        #expect(pullRequest.number == 26288)
        #expect(pullRequest.title == "Display PR titles in sidebar rows")
        #expect(pullRequest.label == "PR")
        #expect(pullRequest.url == URL(string: "https://github.com/CompanyCam/Company-Cam-API/pull/26288"))
        #expect(pullRequest.ownerLogin == "BrianBusby")
        #expect(pullRequest.ownerURL == URL(string: "https://github.com/BrianBusby"))
        #expect(pullRequest.statusRawValue == "merged")
        #expect(pullRequest.branch == "fix/sidebar-pr-title")
    }
}
