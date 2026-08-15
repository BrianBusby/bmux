import Foundation
import BmuxSidebar
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct SidebarWorkspaceSnapshotBuilderMetadataTests {
    @Test
    func metadataBlocksExcludeDisplayedPromptDuplicate() {
        let displayedPrompt = "ok I see that functionality on this build now"
        let blocks = [
            SidebarMetadataBlock(
                key: "last-prompt",
                markdown: " ok I see that\nfunctionality on this build now ",
                priority: 10,
                timestamp: Date(timeIntervalSince1970: 2)
            ),
            SidebarMetadataBlock(
                key: "notes",
                markdown: "Keep this note visible",
                priority: 9,
                timestamp: Date(timeIntervalSince1970: 1)
            ),
        ]

        let filtered = SidebarWorkspaceSnapshotBuilder.metadataBlocks(
            blocks,
            latestNotificationText: nil,
            latestSubmittedMessage: displayedPrompt,
            latestConversationMessage: nil,
            hidesAllDetails: false,
            iMessageModeEnabled: true,
            hiddenPullRequestNumbers: []
        )

        #expect(filtered.map(\.key) == ["notes"])
    }
}
