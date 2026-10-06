import BMUXMobileCore
import BmuxMobileShellModel
import Foundation
import Testing
@testable import BmuxMobileRPC

@Suite struct MobileWorkspaceCardMetadataTests {
    @Test func workspaceListResponseDecodesWorkspaceCardMetadata() throws {
        let json = Data("""
        {
          "workspaces": [
            {
              "id": "ws-1",
              "title": "Workspace",
              "is_selected": true,
              "ticket_title": "Add mobile section creation",
              "ticket_id": "INP-2409",
              "project_title": "One off Advanced Checklists",
              "work_summary": "Reviewing new section creation and placement controls.",
              "pull_request_number": 11565,
              "pull_request_title": "Add section creation and placement controls",
              "pull_request_url": "https://github.com/example/repo/pull/11565",
              "owner_name": "BrianBusby",
              "owner_avatar_url": "https://github.com/BrianBusby.png",
              "branch": "plat-894-mobile-dev-view-main",
              "is_dirty": true,
              "last_prompt": "do an adversarial review of this pr",
              "terminals": []
            }
          ]
        }
        """.utf8)

        let response = try MobileSyncWorkspaceListResponse.decode(json)
        let remote = try #require(response.workspaces.first)
        let workspace = MobileWorkspacePreview(remote: remote)
        #expect(workspace.ticketTitle == "Add mobile section creation")
        #expect(workspace.ticketID == "INP-2409")
        #expect(workspace.projectTitle == "One off Advanced Checklists")
        #expect(workspace.pullRequestNumber == 11565)
        #expect(workspace.ownerName == "BrianBusby")
        #expect(workspace.branch == "plat-894-mobile-dev-view-main")
        #expect(workspace.isDirty == true)
        #expect(workspace.lastPrompt == "do an adversarial review of this pr")
    }

}
