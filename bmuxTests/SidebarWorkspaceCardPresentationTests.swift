import BmuxSidebar
import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
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

    @Test(arguments: [true, false])
    func workspaceTitleDescriptionRespectsVisibilitySetting(showsDescription: Bool) {
        let snapshot = Self.snapshot(showsWorkspaceDescription: showsDescription)
        #expect(snapshot.cardHeadingTitle == "Repair flashing")
        #expect(snapshot.cardDescription == (showsDescription ? "Review roof inspection" : nil))
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

    @MainActor @Test(arguments: [
        (nil, nil),
        ("Repair flashing", "Review roof inspection"),
        ("Review roof inspection", nil),
        (" ", nil),
    ] as [(String?, String?)])
    func referenceRailUsesAuthoritativeTitleAndPreservesContext(ticketTitle: String?, expectedSummary: String?) throws {
        let workspace = Workspace(title: "Terminal")
        workspace.setCustomTitle("Review roof inspection")
        workspace.setCustomDescription("Check the latest inspection photos")
        let provenance = try Self.referenceProvenance(workspaceID: workspace.id, ticketTitle: ticketTitle)
        let card = Self.referenceCard(workspace: workspace, provenance: provenance)
        let normalizedTicket = ticketTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(card.title == (normalizedTicket.flatMap { $0.isEmpty ? nil : $0 } ?? "Review roof inspection"))
        #expect(card.summary == expectedSummary)
        #expect(card.prompt == "Check the latest inspection photos")
        #expect(card.ticketID == (ticketTitle == nil ? nil : "ROOF-42"))
        #expect(card.projectTitle == "Maple Street roof")
        #expect(card.pullRequestText?.hasPrefix("#42") == true)
        #expect(card.ownerName == (ticketTitle == nil ? "sam" : "Sam"))
        #expect(card.branch == "roof-inspection")
        #expect(card.isDirty == false)
        #expect(workspace.customDescription == "Check the latest inspection photos")
    }

    @MainActor @Test(arguments: [nil, "Repair flashing"] as [String?])
    func referenceRailTitleAndPromptUpdatesRemainSeparate(ticketTitle: String?) throws {
        let workspace = Workspace(title: "Terminal")
        workspace.setCustomTitle("Review roof inspection")
        workspace.setCustomDescription("Check the latest inspection photos")
        let initial = Self.referenceCard(workspace: workspace, provenance: try Self.referenceProvenance(
            workspaceID: workspace.id, ticketTitle: ticketTitle
        ))
        workspace.setCustomTitle("Review gutter installation")
        let updated = Self.referenceCard(workspace: workspace, provenance: try Self.referenceProvenance(
            workspaceID: workspace.id, ticketTitle: ticketTitle, prompt: "Compare the new gutter photos"
        ))
        #expect(updated.title == (ticketTitle ?? "Review gutter installation"))
        #expect(updated.summary == (ticketTitle == nil ? nil : "Review gutter installation"))
        #expect(updated.prompt == "Compare the new gutter photos")
        #expect(updated.summary != updated.prompt)
        #expect(updated.projectTitle == initial.projectTitle)
        #expect(updated.ownerName == initial.ownerName)
        #expect(updated.branch == initial.branch)
        #expect(workspace.customDescription == "Check the latest inspection photos")
    }

    @MainActor @Test func referenceRailWithoutProvenanceOmitsStoredPromptDescription() {
        let workspace = Workspace(title: "Review roof inspection")
        workspace.setCustomDescription("Check the latest inspection photos")
        let card = Self.referenceCard(workspace: workspace, provenance: nil)
        #expect(card.title == "Review roof inspection")
        #expect(card.summary == nil)
        #expect(workspace.customDescription == "Check the latest inspection photos")
    }

    @MainActor @Test func referenceRailWaitsForPEBeforeShowingAmbientTicketAndBranch() {
        let workspace = Workspace(title: "Review roof inspection")
        workspace.gitBranch = .init(branch: "roof-99-unrelated-main-checkout", isDirty: true)
        #expect(workspace.sidebarMetadata.workContext.ticket?.key == "ROOF-99")
        let card = Self.referenceCard(workspace: workspace, provenance: nil)
        #expect(card.ticketID == nil)
        #expect(card.ticketURL == nil)
        #expect(card.branch == nil)
        #expect(card.isDirty == nil)
    }

    @MainActor @Test func referenceRailWaitsForBranchConfirmationEvenWhenPEHasOtherFields() throws {
        let workspace = Workspace(title: "Review roof inspection")
        workspace.gitBranch = .init(branch: "roof-99-unrelated-main-checkout", isDirty: true)
        #expect(workspace.sidebarMetadata.workContext.ticket?.key == "ROOF-99")
        let provenance = try #require(WorkspaceDisplayCurrentStateSnapshot(.init(
            id: "roof-work", workspaceID: workspace.stableId.uuidString,
            currentDirectory: workspace.currentDirectory, title: "Review roof inspection",
            lastSubmittedPrompt: "Compare the new gutter photos",
            observedAt: Date(), updatedAt: Date()
        )))
        let card = Self.referenceCard(workspace: workspace, provenance: provenance)
        #expect(card.prompt == "Compare the new gutter photos")
        #expect(card.ticketID == nil)
        #expect(card.branch == nil)
        #expect(card.isDirty == nil)
    }

    @MainActor @Test func referenceRailHidesOldContextUntilPEConfirmsNewWorktree() throws {
        let workspace = Workspace(title: "Review roof inspection")
        workspace.currentDirectory = "/tmp/roof-gutter-worktree"
        let old = try Self.referenceProvenance(
            workspaceID: workspace.stableId, ticketTitle: "Repair flashing",
            currentDirectory: "/tmp/roof-main-checkout", branch: "main"
        )
        let pending = Self.referenceCard(workspace: workspace, provenance: old)
        #expect(pending.title == "Older roof overview")
        #expect(pending.ticketID == nil)
        #expect(pending.branch == nil)
        #expect(pending.isDirty == nil)
        let confirmed = Self.referenceCard(workspace: workspace, provenance: try Self.referenceProvenance(
            workspaceID: workspace.stableId, ticketTitle: "Repair flashing",
            currentDirectory: workspace.currentDirectory, branch: "roof-42-gutter-worktree"
        ))
        #expect(confirmed.title == "Repair flashing")
        #expect(confirmed.ticketID == "ROOF-42")
        #expect(confirmed.branch == "roof-42-gutter-worktree")
    }

    @Test func peDisplayUsesInspectedWorktreeBranchInsteadOfCachedMainBranch() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let client = try ProvenanceEngineClientFactory().defaultSQLiteClient(homeDirectory: home)
        let directory = "/tmp/roof-gutter-worktree"
        let git = WorkProvenanceGitSnapshot(
            repositoryRoot: directory, commonDirectory: "/tmp/roof-main-checkout/.git", remoteSlug: nil,
            branch: "roof-42-gutter-worktree", headCommit: "abc123", isDirty: false, statusEntries: []
        )
        let service = WorkProvenanceObservationService(client: client, gitInspector: CardGitInspector(snapshot: git))
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(), stableWorkspaceID: UUID(), title: "Review roof inspection",
            currentDirectory: directory, branch: "main"
        )
        await service.observeWorkspaceSnapshot(workspace)
        let display = try await client.workspaceDisplay(.init(workspaceID: workspace.stableWorkspaceID.uuidString))
        #expect(display.display?.currentDirectory == directory)
        #expect(display.display?.branch == "roof-42-gutter-worktree")
        #expect(display.display?.ticketIDs.isEmpty == true)
        let detached = WorkProvenanceGitSnapshot(
            repositoryRoot: directory, commonDirectory: git.commonDirectory, remoteSlug: nil,
            branch: nil, headCommit: "def456", isDirty: false, statusEntries: []
        )
        let detachedService = WorkProvenanceObservationService(
            client: client, gitInspector: CardGitInspector(snapshot: detached)
        )
        await detachedService.observeWorkspaceSnapshot(workspace)
        let cleared = try await client.workspaceDisplay(.init(workspaceID: workspace.stableWorkspaceID.uuidString))
        #expect(cleared.display?.branch == nil)
    }

    private struct CardGitInspector: WorkProvenanceGitInspecting {
        let snapshot: WorkProvenanceGitSnapshot
        func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot? {
            directory == snapshot.repositoryRoot ? snapshot : nil
        }
    }

    @MainActor private static func referenceCard(
        workspace: Workspace, provenance: WorkspaceDisplayCurrentStateSnapshot?
    ) -> WorkspaceReferenceCardSnapshot {
        let title = SidebarWorkspaceTitleResolution(
            liveTitle: workspace.title, liveTitleIsAuthoritative: workspace.hasCustomTitle, provenanceTitle: provenance?.title
        ).title
        return WorkspaceReferenceCardSnapshot(workspace: workspace, provenance: provenance, workspaceTitle: title)
    }

    private static func referenceProvenance(
        workspaceID: UUID, ticketTitle: String?, prompt: String = "Check the latest inspection photos",
        currentDirectory: String? = nil, branch: String = "roof-inspection"
    ) throws -> WorkspaceDisplayCurrentStateSnapshot {
        let record = ProvenanceWorkspaceDisplayRecord(
            id: "roof-work", workspaceID: workspaceID.uuidString,
            currentDirectory: currentDirectory, title: "Older roof overview", branch: branch,
            pullRequestNumber: 42, pullRequestOwnerLogin: "sam", pullRequestStatus: "open", isDirty: false,
            ticketLinks: ticketTitle.map { [.init(
                id: "ROOF-42", system: "linear", title: $0, ownerName: "Sam"
            )] } ?? [],
            projectLinks: [.init(id: "roof", system: "linear", title: "Maple Street roof")],
            currentWorkSummary: "Check the latest inspection photos", lastSubmittedPrompt: prompt,
            observedAt: Date(timeIntervalSince1970: 900), updatedAt: Date(timeIntervalSince1970: 900)
        )
        return try #require(WorkspaceDisplayCurrentStateSnapshot(record))
    }

    private static func snapshot(
        title: String = "Review roof inspection",
        ticketTitle: String? = "Repair flashing",
        customDescription: String? = "Check the latest inspection photos",
        prompt: String? = "Check the latest inspection photos",
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
                provenanceDisplaySnapshot: nil,
                titleResolution: .init(liveTitle: title, liveTitleIsAuthoritative: true, provenanceTitle: nil)
            ),
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
