import BmuxSidebar
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite struct SidebarWorkspaceCardPresentationTests {
    @Test(arguments: [
        ("Roof inspection" as String?, "Inspecting roof flashing", "Inspecting roof flashing" as String?),
        (nil, "Inspecting roof flashing", nil),
        ("Inspecting roof flashing", "Inspecting roof flashing", nil),
        (" Inspecting roof flashing ", "Inspecting roof flashing", nil),
        ("Roof inspection", "", nil),
        ("Roof inspection", " \n ", nil),
    ]) func descriptionUsesWorkspaceTitleWithoutDuplicatingHeading(
        ticketTitle: String?, title: String, expected: String?
    ) {
        let snapshot = Self.snapshot(ticketTitle: ticketTitle, title: title)

        #expect(snapshot.cardDescription == expected)
        #expect(snapshot.customDescription == "Check flashing around the chimney")
    }

    @Test func titleDescriptionDoesNotRequireStoredDescription() {
        let snapshot = Self.snapshot(customDescription: nil)

        #expect(snapshot.cardDescription == "Inspecting roof flashing")
        #expect(snapshot.customDescription == nil)
    }

    @Test func hiddenDescriptionRemainsHidden() {
        #expect(Self.snapshot(showsWorkspaceDescription: false).cardDescription == nil)
    }

    @Test func titleUpdateRefreshesDescriptionDuringContextMenu() throws {
        let current = Self.snapshot()
        let next = Self.snapshot(title: "Checking chimney flashing")
        let decision = SidebarWorkspaceSnapshotRefreshPolicy().decision(
            current: current, next: next, force: false, contextMenuVisible: true
        )
        let displayed = try #require(decision.workspaceSnapshotStorage)

        #expect(displayed.cardDescription == "Checking chimney flashing")
        #expect(displayed.ticketTitle == current.ticketTitle)
        #expect(displayed.latestSubmittedMessage == current.latestSubmittedMessage)
        #expect(displayed.customDescription == current.customDescription)
        #expect(displayed.ticketRows == current.ticketRows)
        #expect(displayed.projectRows == current.projectRows)
        #expect(displayed.pullRequestRows == current.pullRequestRows)
        #expect(displayed.branchDirectoryLines == current.branchDirectoryLines)
        #expect(decision.pendingWorkspaceSnapshot == nil)
    }

    @Test func promptUpdateAppearsOnceInFooterAndDoesNotReplaceDescription() throws {
        let current = Self.snapshot()
        let prompt = "Also check the skylight seal"
        let next = Self.snapshot(customDescription: prompt, latestSubmittedMessage: prompt)
        let decision = SidebarWorkspaceSnapshotRefreshPolicy().decision(
            current: current, next: next, force: false, contextMenuVisible: false
        )
        let displayed = try #require(decision.workspaceSnapshotStorage)
        let footer = SidebarWorkspaceRowLineLimitPolicy.subtitle(
            notificationText: nil,
            conversationMessage: SidebarWorkspaceRowLineLimitPolicy.conversationMessage(
                latestSubmittedMessage: displayed.latestSubmittedMessage,
                latestConversationMessage: "Earlier agent reply",
                hidesAllDetails: false,
                iMessageModeEnabled: true
            )
        )

        #expect(displayed.cardDescription == current.title)
        #expect(footer?.text == prompt)
        #expect([displayed.cardDescription, footer?.text].compactMap { $0 }.filter { $0 == prompt }.count == 1)
        #expect(displayed.ticketRows == current.ticketRows)
        #expect(displayed.projectRows == current.projectRows)
        #expect(displayed.pullRequestRows == current.pullRequestRows)
        #expect(displayed.branchDirectoryLines == current.branchDirectoryLines)
        #expect(displayed.customDescription == prompt)
    }

    private static func snapshot(
        ticketTitle: String? = "Roof inspection",
        title: String = "Inspecting roof flashing",
        customDescription: String? = "Check flashing around the chimney",
        latestSubmittedMessage: String = "Check flashing around the chimney",
        showsWorkspaceDescription: Bool = true
    ) -> SidebarWorkspaceSnapshotBuilder.Snapshot {
        SidebarWorkspaceSnapshotBuilder.Snapshot(
            presentationKey: .init(
                showsWorkspaceDescription: showsWorkspaceDescription,
                usesVerticalBranchLayout: true,
                showsGitBranch: true,
                usesViewportAwarePath: false,
                visibleAuxiliaryDetails: .init(
                    showsMetadata: true, showsLog: true, showsProgress: true,
                    showsBranchDirectory: true, showsPullRequests: true, showsPorts: true
                ),
                provenanceDisplaySnapshot: nil
            ),
            ticketTitle: ticketTitle,
            title: title,
            customDescription: showsWorkspaceDescription ? customDescription : nil,
            isPinned: false,
            customColorHex: nil,
            remoteWorkspaceSidebarText: nil,
            remoteConnectionStatusText: "",
            remoteStateHelpText: "",
            showsRemoteReconnectAffordance: false,
            copyableSidebarSSHError: nil,
            latestConversationMessage: nil,
            latestSubmittedMessage: latestSubmittedMessage,
            metadataEntries: [],
            metadataBlocks: [],
            latestLog: nil,
            progress: nil,
            compactGitBranchSummaryText: "roof-inspection",
            compactDirectoryCandidates: [],
            compactBranchDirectoryCandidates: [],
            branchDirectoryLines: [.init(branch: "roof-inspection", directoryCandidates: ["Maple Street"])],
            branchLinesContainBranch: true,
            pullRequestRows: [.init(
                id: "pr#42", number: 42, title: "Record roof inspection findings", label: "PR",
                url: nil, status: .open, ownerLogin: "Brian", ownerURL: nil,
                isStale: false, isFromProvenance: false
            )],
            projectRows: [.init(id: "maple-street", title: "Maple Street Roof Inspection", url: nil)],
            ticketRows: [.init(id: "ROOF-42", title: ticketTitle, url: nil, ownerName: "Brian", ownerURL: nil)],
            listeningPorts: [],
            finderDirectoryPath: nil,
            repoBadgeAppearance: nil,
            mediaActivity: .init(),
            hasActiveAIWork: false
        )
    }
}
