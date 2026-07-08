import Foundation
import Testing
import BmuxTerminalCore

@Suite struct TerminalOpenURLFileRoutingPolicyTests {
    private let policy = TerminalOpenURLFileRoutingPolicy()

    @Test func explicitFileSchemeBypassesBmuxFileRouting() throws {
        let url = try #require(URL(string: "file:///Users/dev/out/ab_cosyvoice_emo.wav"))
        #expect(
            policy.shouldAttemptBmuxFileRouting(
                rawOpenURLValue: url.absoluteString,
                target: .external(url)
            ) == false
        )
    }

    @Test func localhostFileSchemeBypassesBmuxFileRouting() throws {
        let url = try #require(URL(string: "file://localhost/Users/dev/out/ab_cosyvoice_emo.wav"))
        #expect(
            policy.shouldAttemptBmuxFileRouting(
                rawOpenURLValue: url.absoluteString,
                target: .external(url)
            ) == false
        )
    }

    @Test func hostedFileTargetBypassesBmuxFileRoutingEvenWithoutRawScheme() throws {
        let url = try #require(URL(string: "file://remote-host/Users/dev/out/ab_cosyvoice_emo.wav"))
        #expect(
            policy.shouldAttemptBmuxFileRouting(
                rawOpenURLValue: "/Users/dev/out/ab_cosyvoice_emo.wav",
                target: .external(url)
            ) == false
        )
    }

    @Test func absolutePathCanStillUseBmuxFileRouting() {
        let url = URL(fileURLWithPath: "/Users/dev/project/README.md")
        #expect(
            policy.shouldAttemptBmuxFileRouting(
                rawOpenURLValue: "/Users/dev/project/README.md",
                target: .external(url)
            )
        )
    }

    @Test func nonFileTargetsBypassBmuxFileRouting() throws {
        let url = try #require(URL(string: "https://example.com/audio.wav"))
        #expect(
            policy.shouldAttemptBmuxFileRouting(
                rawOpenURLValue: url.absoluteString,
                target: .embeddedBrowser(url)
            ) == false
        )
    }
}
