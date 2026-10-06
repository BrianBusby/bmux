import BmuxSidebar
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite struct SidebarWorkspaceCardPresentationTests {
    @Test(arguments: [
        (nil, "Review roof inspection", nil),
        ("Repair flashing", "Review roof inspection", "Review roof inspection"),
        ("Review roof inspection", "Review roof inspection", nil),
        (" Review roof inspection ", "Review roof inspection", nil),
        (" ", "Review roof inspection", nil),
        ("Repair flashing", " ", nil),
    ] as [(String?, String, String?)])
    func workspaceTitleOccupiesDescriptionOnlyUnderDistinctTicketHeading(
        ticketTitle: String?, workspaceTitle: String, expectedDescription: String?
    ) {
        let snapshot = Self.snapshot(title: workspaceTitle, ticketTitle: ticketTitle)
        #expect(snapshot.cardDescription == expectedDescription)
        let normalizedTicket = ticketTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(snapshot.cardHeadingTitle == (normalizedTicket.flatMap { $0.isEmpty ? nil : $0 } ?? workspaceTitle))
        #expect(snapshot.customDescription == "Check the latest inspection photos")
        #expect(snapshot.latestSubmittedMessage == "Check the latest inspection photos")
    }

    @Test func workspaceTitleDoesNotDependOnStoredDescription() {
        let snapshot = Self.snapshot(customDescription: nil)
        #expect(snapshot.cardHeadingTitle == "Repair flashing")
        #expect(snapshot.cardDescription == "Review roof inspection")
        #expect(snapshot.customDescription == nil)
    }

    @Test func titleUpdateReprojectsDescriptionWhileContextMenuIsOpen() throws {
        let current = Self.snapshot()
        let next = Self.snapshot(title: "Review gutter installation")
        let decision = SidebarWorkspaceSnapshotRefreshPolicy().decision(
            current: current, next: next, force: false, contextMenuVisible: true
        )
        let displayed = try #require(decision.workspaceSnapshotStorage)
        #expect(displayed.cardHeadingTitle == "Repair flashing")
        #expect(displayed.cardDescription == "Review gutter installation")
        #expect(displayed.customDescription == current.customDescription)
        #expect(displayed.latestSubmittedMessage == current.latestSubmittedMessage)
    }

    @Test func ticketRemovalLeavesWorkspaceTitleOnlyInHeading() throws {
        let current = Self.snapshot()
        let next = Self.snapshot(ticketTitle: nil)
        let decision = SidebarWorkspaceSnapshotRefreshPolicy().decision(
            current: current, next: next, force: false, contextMenuVisible: true
        )
        let displayed = try #require(decision.workspaceSnapshotStorage)
        #expect(displayed.cardHeadingTitle == "Review roof inspection")
        #expect(displayed.cardDescription == nil)
    }

    @Test func promptUpdateRemainsInFooterWithoutChangingTitleDescription() throws {
        let current = Self.snapshot()
        let next = Self.snapshot(prompt: "Compare the new gutter photos")
        let policy = SidebarWorkspaceSnapshotRefreshPolicy()
        let deferred = policy.decision(current: current, next: next, force: false, contextMenuVisible: true)
        #expect(deferred.workspaceSnapshotStorage?.cardDescription == "Review roof inspection")
        #expect(deferred.workspaceSnapshotStorage?.latestSubmittedMessage == current.latestSubmittedMessage)
        let displayed = try #require(policy.decision(
            current: deferred.workspaceSnapshotStorage, next: next, force: false, contextMenuVisible: false
        ).workspaceSnapshotStorage)
        #expect(displayed.cardDescription == "Review roof inspection")
        #expect(displayed.cardDescription != displayed.latestSubmittedMessage)
        #expect(displayed.latestSubmittedMessage == "Compare the new gutter photos")
        #expect(displayed.customDescription == current.customDescription)
        #expect(displayed.ticketRows == current.ticketRows)
        #expect(displayed.projectRows == current.projectRows)
        #expect(displayed.pullRequestRows == current.pullRequestRows)
        #expect(displayed.compactGitBranchSummaryText == current.compactGitBranchSummaryText)
    }

    private static func snapshot(
        title: String = "Review roof inspection",
        ticketTitle: String? = "Repair flashing",
        customDescription: String? = "Check the latest inspection photos",
        prompt: String? = "Check the latest inspection photos"
    ) -> SidebarWorkspaceSnapshotBuilder.Snapshot {
        SidebarWorkspaceSnapshotBuilder.Snapshot(
            presentationKey: .init(
                showsWorkspaceDescription: true,
                usesVerticalBranchLayout: true,
                showsGitBranch: true,
                usesViewportAwarePath: false,
                visibleAuxiliaryDetails: .init(
                    showsMetadata: true, showsLog: true, showsProgress: true,
                    showsBranchDirectory: true, showsPullRequests: true, showsPorts: true
                ),
                provenanceDisplaySnapshot: nil,
                titleResolution: .init(liveTitle: title, liveTitleIsAuthoritative: true, provenanceTitle: nil)
            ),
            title: title,
            customDescription: customDescription,
            isPinned: false,
            customColorHex: nil,
            remoteWorkspaceSidebarText: nil,
            remoteConnectionStatusText: "",
            remoteStateHelpText: "",
            showsRemoteReconnectAffordance: false,
            copyableSidebarSSHError: nil,
            latestConversationMessage: nil,
            latestSubmittedMessage: prompt,
            metadataEntries: [],
            metadataBlocks: [],
            latestLog: nil,
            progress: nil,
            compactGitBranchSummaryText: "roof-inspection",
            isDirty: false,
            compactDirectoryCandidates: [],
            compactBranchDirectoryCandidates: [],
            branchDirectoryLines: [],
            branchLinesContainBranch: true,
            pullRequestRows: [.init(
                id: "pr#42", number: 42, title: "Review roof photos", label: "PR", url: nil,
                status: .open, ownerLogin: "sam", ownerURL: nil, branch: "roof-inspection",
                isStale: false, isFromProvenance: false
            )],
            projectRows: [.init(id: "roof", title: "Maple Street roof", url: nil)],
            ticketRows: ticketTitle.map { [.init(
                id: "ROOF-42", title: $0, url: nil, ownerName: "Sam", ownerURL: nil
            )] } ?? [],
            listeningPorts: [],
            finderDirectoryPath: nil,
            repoBadgeAppearance: nil,
            mediaActivity: .init(),
            hasActiveAIWork: false
        )
    }
}
