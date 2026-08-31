import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite struct SidebarWorkspaceRowLineLimitPolicyTests {
    @Test func workspaceTitlesUseAtMostThreeLinesWhenWrappingIsEnabled() {
        #expect(SidebarWorkspaceRowLineLimitPolicy.titleLineLimit(wrapsWorkspaceTitles: true) == 3)
    }

    @Test func workspaceTitlesStaySingleLineWhenWrappingIsDisabled() {
        #expect(SidebarWorkspaceRowLineLimitPolicy.titleLineLimit(wrapsWorkspaceTitles: false) == 1)
    }

    @Test func linkedTitlesUseAtMostThreeLinesWhenWrappingIsEnabled() {
        #expect(SidebarWorkspaceRowLineLimitPolicy.linkedTitleLineLimit(wrapsWorkspaceTitles: true) == 3)
    }

    @Test func linkedTitlesStaySingleLineWhenWrappingIsDisabled() {
        #expect(SidebarWorkspaceRowLineLimitPolicy.linkedTitleLineLimit(wrapsWorkspaceTitles: false) == 1)
    }

    @Test func workspaceTitleWrappingIsEnabledByDefault() {
        #expect(SidebarWorkspaceTitleWrapSettings.defaultWrap)
    }

    @Test func conversationSubtitleCanUseThreeLines() throws {
        let subtitle = try #require(SidebarWorkspaceRowLineLimitPolicy.subtitle(
            notificationText: nil,
            conversationMessage: "First line\nSecond line\nThird line"
        ))

        #expect(subtitle.text == "First line\nSecond line\nThird line")
        #expect(subtitle.lineLimit == 3)
    }

    @Test func notificationSubtitleStaysCompactAndWinsOverConversation() throws {
        let subtitle = try #require(SidebarWorkspaceRowLineLimitPolicy.subtitle(
            notificationText: "Build finished",
            conversationMessage: "A longer conversation summary"
        ))

        #expect(subtitle.text == "Build finished")
        #expect(subtitle.lineLimit == 2)
    }

    @Test func conversationSubtitlePrefersSubmittedPromptOverAssistantReply() {
        let subtitle = SidebarWorkspaceRowLineLimitPolicy.conversationMessage(
            latestSubmittedMessage: "last prompt I submitted",
            latestConversationMessage: "assistant response that arrived later",
            hidesAllDetails: false,
            iMessageModeEnabled: true
        )

        #expect(subtitle == "last prompt I submitted")
    }

    @Test func conversationSubtitleHidesDisplayedPullRequestPrompt() {
        let subtitle = SidebarWorkspaceRowLineLimitPolicy.conversationMessage(
            latestSubmittedMessage: "do an adversarial review of this pr: https://github.com/CompanyCam/Company-Cam-API/pull/25964",
            latestConversationMessage: nil,
            hidesAllDetails: false,
            iMessageModeEnabled: true,
            hiddenPullRequestNumbers: [25964]
        )

        #expect(subtitle == nil)
    }

    @Test func conversationSubtitleKeepsDifferentPullRequestPrompt() {
        let subtitle = SidebarWorkspaceRowLineLimitPolicy.conversationMessage(
            latestSubmittedMessage: "do an adversarial review of this pr: https://github.com/CompanyCam/Company-Cam-API/pull/25964",
            latestConversationMessage: nil,
            hidesAllDetails: false,
            iMessageModeEnabled: true,
            hiddenPullRequestNumbers: [12345]
        )

        #expect(subtitle != nil)
    }

    @Test func conversationSubtitleDoesNotFallBackToAssistantReply() {
        let subtitle = SidebarWorkspaceRowLineLimitPolicy.conversationMessage(
            latestSubmittedMessage: nil,
            latestConversationMessage: "assistant response that arrived later",
            hidesAllDetails: false,
            iMessageModeEnabled: true
        )

        #expect(subtitle == nil)
    }

    @Test func conversationSubtitleIsHiddenOutsideIMessageDetails() {
        #expect(SidebarWorkspaceRowLineLimitPolicy.conversationMessage(
            latestSubmittedMessage: "last prompt I submitted",
            latestConversationMessage: "assistant response",
            hidesAllDetails: true,
            iMessageModeEnabled: true
        ) == nil)
        #expect(SidebarWorkspaceRowLineLimitPolicy.conversationMessage(
            latestSubmittedMessage: "last prompt I submitted",
            latestConversationMessage: "assistant response",
            hidesAllDetails: false,
            iMessageModeEnabled: false
        ) == nil)
    }

    @Test func blankConversationSubtitleIsHidden() {
        #expect(SidebarWorkspaceRowLineLimitPolicy.subtitle(
            notificationText: nil,
            conversationMessage: " \n "
        ) == nil)
    }
}
