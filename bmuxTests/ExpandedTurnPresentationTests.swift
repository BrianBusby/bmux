import Foundation
import ProvenanceEngineContracts
import Testing
#if canImport(AppKit)
import AppKit
import SwiftUI
#endif
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#elseif canImport(TurnPresentationHarness)
@testable import TurnPresentationHarness
#endif

@Suite struct ExpandedTurnPresentationTests {
    @Test func repliesAndRawSources() {
        let raw = " \n<send_user_message_question_reply>\n[{\"question\":\"Which base?\",\"answer\":\"708\",\"questionItemId\":1},{\"question\":\"Build?\",\"answer\":\"Yes\"}]\n</send_user_message_question_reply> \n"
        let value = ExpandedTurnRequest(objective: raw, prompt: raw.trimmingCharacters(in: .whitespacesAndNewlines))
        #expect(value.identical)
        #expect(value.objective == raw)
        #expect(value.replies?.map(\.answer) == ["708", "Yes"])
        #expect(ExpandedTurnRequest(objective: raw, prompt: "different").identical == false)
        #expect(ExpandedTurnRequest(objective: nil, prompt: raw).replies == nil)
    }
    @Test(arguments: ["[]", "{}", "[{}]", "[{\"question\":\"Q\"}]", "[{\"question\":1,\"answer\":\"A\"}]", "[{\"question\":\" \",\"answer\":\"A\"}]", "broken"])
    func invalidReplies(payload: String) {
        let raw = "<send_user_message_question_reply>\(payload)</send_user_message_question_reply>"
        let request = ExpandedTurnRequest(objective: raw, prompt: nil)
        #expect(request.replies == nil)
        #expect(request.objective == raw)
    }
    @Test(arguments: ["plain text", "<unsupported>[]</unsupported>", "<send_user_message_question_reply>[]"])
    func plainFallback(raw: String) { #expect(ExpandedTurnRequest(objective: raw, prompt: nil).replies == nil) }
    @Test func literalDeduplication() {
        #expect(ExpandedTurnRequest.visibleSummary(" \n", finalOutput: "answer") == nil)
        #expect(ExpandedTurnRequest.visibleSummary(" answer ", finalOutput: "\nanswer\n") == nil)
        #expect(ExpandedTurnRequest.visibleSummary("answer", finalOutput: "The answer is here") == nil)
        #expect(ExpandedTurnRequest.visibleSummary("a  b", finalOutput: "a b") == "a  b")
        #expect(ExpandedTurnRequest.visibleSummary(" distinct ", finalOutput: nil) == " distinct ")
        #expect(!ExpandedTurnRequest(objective: "a  b", prompt: "a b").identical)
        #expect(!ExpandedTurnRequest(objective: "\u{00E9}", prompt: "e\u{0301}").identical)
        #expect(ExpandedTurnRequest.visibleSummary("\u{00E9}", finalOutput: "e\u{0301}") != nil)
        #expect(!ExpandedTurnRequest(objective: nil, prompt: "  ").hasPrompt)
    }
    @Test(arguments: [
        ("'A=b' git status", ExpandedTurnCommandCategory.other),
        ("A\\=b git status", .other),
        ("sed -n '1p' -e 'w output.txt' file", .other),
        ("git diff;; echo next", .other),
        ("git diff &&", .other),
        ("npm uninstall test", .other),
        ("npm exec test", .other),
        ("git\u{00A0}diff", .other),
        ("./scripts/test-unit.sh", .build),
        ("./scripts/run-tests-v2.sh", .build),
        ("./scripts/reloadp.sh", .build),
        ("git diff -- file.swift && sed -n '1,2p' file.swift", ExpandedTurnCommandCategory.git),
        ("/bin/zsh -lc 'cd /repo && KEY=value git status'", .git),
        ("/bin/zsh -c 'git diff -- '\\''a b.swift'\\'''", .git),
        ("cd /repo; swift test && git status", .build),
        ("A=b B='two words' rg 'git diff' Sources", .read),
        ("cat 'git status.swift'", .read),
        ("sed -i '' 's/a/b/' file", .edit),
        ("sed -n '1,2p' file", .read),
        ("apply_patch patch.txt", .edit),
        ("./scripts/reload.sh --tag example", .build),
        ("bmux list-workspaces", .bmux),
        ("echo 'git diff'", .other),
        ("# git diff\ncat file", .read),
        ("if true; then git status; fi", .other),
        ("cat $(git status)", .other),
        ("git status | cat", .other),
        ("'git diff' file", .other),
        ("git 'unterminated", .other)
    ])
    func categories(raw: String, expected: ExpandedTurnCommandCategory) {
        let value = ExpandedTurnCommandPresentation(raw: raw)
        #expect(value.category == expected)
        #expect(value.raw == raw)
        #expect(value == ExpandedTurnCommandPresentation(raw: raw))
    }
    @Test func proxyAndBounds() {
        let raw = "bmux agent-token-proxy --command-hex " + String(repeating: "ab", count: 200)
        let proxy = ExpandedTurnCommandPresentation(raw: raw)
        #expect(ExpandedTurnCommandPresentation(raw: "printf '%s\\n' 'a b'").preview == "printf '%s\\n' 'a b'")
        #expect(ExpandedTurnCommandPresentation(raw: "/bin/zsh -c 'cd /repo && echo hello'").preview == "echo hello")
        #expect(ExpandedTurnCommandPresentation(raw: "echo hi&&git status").preview == "echo hi")
        #expect(proxy.category == .bmux)
        #expect(proxy.isProxy)
        #expect(proxy.preview != raw)
        #expect(proxy.preview.hasSuffix("…"))
        #expect(ExpandedTurnCommandPresentation(raw: "cat file?.swift").target == nil)
        let huge = "git " + String(repeating: "x", count: 70_000)
        #expect(ExpandedTurnCommandPresentation(raw: huge).category == .other)
        #expect(ExpandedTurnCommandPresentation(raw: huge).raw == huge)
    }
    #if canImport(bmux_DEV) || canImport(bmux) || canImport(TurnPresentationHarness)
    @Test @MainActor func expandedEvidenceContrastsWithDarkWorkspaceUnderEitherSystemAppearance() throws {
        let turn = ProvenanceCodingAgentTurnRecord(id: "roof-turn", sessionID: "roof-session", provider: "codex",
            providerTurnID: "provider-turn", status: "started", updatedAt: Date(), source: .observed, confidence: .high)
        let detail = ProvenanceFactualSessionProjectionTurnSnapshot(turn: turn, submittedPrompt: nil,
            currentPlan: nil, completedCommands: [], visibleReasoningSummaries: [], fileChangeAttributions: [], assistantMessages: [])
        for dark in [false, true] {
            // The real workspace shell has a fixed dark palette even under Aqua.
            let root = ExpandedTurnDetailView(presentation: .init(reference: .init(turn: turn), detail: detail),
                commands: [], navigation: .constant(.init()))
                .foregroundStyle(Color.white)
                .environment(\.colorScheme, dark ? .dark : .light)
                .frame(width: 640)
            let host = NSHostingView(rootView: root)
            host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            host.setFrameSize(host.fittingSize)
            host.layoutSubtreeIfNeeded()
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            func luminance(_ color: NSColor) -> Double {
                let rgb = color.usingColorSpace(.sRGB)!
                func linear(_ value: CGFloat) -> Double {
                    let x = Double(value)
                    return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
                }
                return 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
            }
            let background = luminance(try #require(bitmap.colorAt(x: bitmap.pixelsWide - 20, y: 20)))
            var brightestText = background
            for y in 12..<min(70, bitmap.pixelsHigh) {
                for x in 12..<min(400, bitmap.pixelsWide) {
                    if let color = bitmap.colorAt(x: x, y: y) { brightestText = max(brightestText, luminance(color)) }
                }
            }
            #expect(background < 0.2, "Expanded evidence must stay on the dark workspace surface (system dark: \(dark))")
            #expect((brightestText + 0.05) / (background + 0.05) >= 4.5, "Evidence text must remain readable (system dark: \(dark))")
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bmux-expanded-contrast-\(dark ? "dark" : "light").png"))
        }
    }

    @Test @MainActor func nativeFixtureLayoutsRemainWithinPanel() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let turn = ProvenanceCodingAgentTurnRecord(id: "fixture-pe-turn", sessionID: "fixture-session", threadID: "fixture-pe-thread", provider: "codex", providerTurnID: "fixture-provider-turn", status: "completed", model: "Recorded model", startedAt: date, completedAt: date.addingTimeInterval(2072), updatedAt: date, source: .observed, confidence: .high)
        let prompt = "<send_user_message_question_reply>[{\"question\":\"Which base should the update use?\",\"answer\":\"Use the current main branch.\"}]</send_user_message_question_reply>"
        let commands = (0..<151).map { index in
            ProvenanceCodingAgentCommandRecord(id: "fixture-command-\(index)", sessionID: turn.sessionID, turnID: turn.id, provider: "codex", command: index == 0 ? "swift test --filter WorkspaceTests" : "git diff -- Sources/Workspace.swift", status: index == 0 ? "failed" : "succeeded", outputSummary: index == 0 ? "Recorded fixture failure: expected workspace title to update." : nil, completedAt: date, source: .observed, confidence: .high)
        }
        let detail = ProvenanceFactualSessionProjectionTurnSnapshot(turn: turn, submittedPrompt: .init(id: "fixture-prompt", sessionID: turn.sessionID, turnID: turn.id, provider: "codex", text: prompt, submittedAt: date, source: .observed, confidence: .high), currentPlan: nil, completedCommands: commands, visibleReasoningSummaries: [], fileChangeAttributions: [], assistantMessages: [.init(id: "fixture-output", sessionID: turn.sessionID, provider: "codex", text: "Fixture only — native expanded turn.\n\n- Keep the current workspace available.\n- Preserve each recorded command and its result.\n\nA completed provider turn does not prove delivery.\n\n" + String(repeating: "LongRecordedIdentifier", count: 14), completedAt: date, source: .observed, confidence: .high)])
        let rows = commands.map { ExpandedTurnCommandRow(record: $0, presentation: .init(raw: $0.command)) }
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bmux-expanded-native-snapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for width in [320.0, 800.0] {
            for dark in [false, true] {
                let root = ExpandedTurnDetailView(presentation: .init(reference: .init(turn: turn), detail: detail), commands: rows, navigation: .constant(.init()))
                    .environment(\.colorScheme, dark ? .dark : .light)
                    .frame(width: width)
                let host = NSHostingView(rootView: root)
                host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                var size = host.fittingSize
                host.setFrameSize(size)
                host.layoutSubtreeIfNeeded()
                size = host.fittingSize
                #expect(size.width <= width + 1)
                #expect(size.height > 500)
                host.setFrameSize(size)
                host.layoutSubtreeIfNeeded()
                let bounds = NSRect(x: 0, y: 0, width: width, height: min(size.height, 2400))
                let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: bounds))
                host.cacheDisplay(in: bounds, to: bitmap)
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: directory.appendingPathComponent("fixture-\(Int(width))-\(dark ? "dark" : "light").png"))
            }
        }
    }
    #endif

    @Test func projectionPreservesFinalAndUnavailableEvidence() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let raw = "  Final output.\n\n- First\n- Second  \n"
        let turn = ProvenanceCodingAgentTurnRecord(id: "pe-turn", sessionID: "session", threadID: "pe-thread", provider: "codex", providerTurnID: "provider-turn", status: "completed", startedAt: date, completedAt: date.addingTimeInterval(10), updatedAt: date, source: .observed, confidence: .high)
        let snapshot = ProvenanceFactualSessionProjectionTurnSnapshot(turn: turn, submittedPrompt: nil, currentPlan: nil, completedCommands: [], visibleReasoningSummaries: [], fileChangeAttributions: [], assistantMessages: [
            ProvenanceCodingAgentAssistantMessageRecord(id: "output", sessionID: "session", provider: "codex", text: raw, completedAt: date, source: .observed, confidence: .high)
        ])
        let detail = ExpandedTurnPresentation(reference: .init(turn: turn), detail: snapshot)
        #expect(detail.finalOutput == raw)
        #expect(detail.summary == nil)
        #expect(detail.duration == 10)
        #expect(detail.count(snapshot.completedCommands.count) == 0)
        let unavailable = ExpandedTurnPresentation(reference: .init(turn: turn), detail: nil)
        #expect(unavailable.count(nil) == nil)
        #expect(unavailable.finalOutput == nil)
        #expect(unavailable.reference.turnID == "pe-turn")
        #expect(unavailable.reference.threadID == "pe-thread")
        let claude = ProvenanceFactualSessionProjectionTurnReference(turnID: "claude-turn", provider: "claude", providerTurnID: "provider", status: "unknown", startedAt: date, updatedAt: date.addingTimeInterval(99))
        let partial = ExpandedTurnPresentation(reference: claude, detail: nil)
        #expect(partial.duration == nil)
        #expect(partial.count(0) == nil)
        #expect(partial.count(3) == 3)
        let invalidDates = ProvenanceFactualSessionProjectionTurnReference(turnID: "invalid", provider: "codex", providerTurnID: "provider", status: "completed", startedAt: date, completedAt: date.addingTimeInterval(-1), updatedAt: date)
        #expect(ExpandedTurnPresentation(reference: invalidDates, detail: nil).duration == nil)
    }
    @Test func classificationPartitionsAvailableRecords() {
        let records = ["git diff", "rg hello Sources", "apply_patch x", "swift test", "bmux list-workspaces", "unsupported", "git status"]
        let categories = records.map { ExpandedTurnCommandPresentation(raw: $0).category }
        let counts = ExpandedTurnCommandCategory.allCases.map { category in categories.filter { $0 == category }.count }
        #expect(counts.reduce(0, +) == records.count)
        #expect(categories.filter { $0 == .other }.count == 1)
    }

    @Test func filterBeforePaginationAndDisclosureIdentity() {
        let categories = (0..<151).map { $0 % 2 == 0 ? ExpandedTurnCommandCategory.git : .other }
        var state = ExpandedTurnCommandNavigation()
        #expect(state.visibleIndices(categories: categories).count == 50)
        state.select(.other)
        #expect(state.visibleIndices(categories: categories) == Array(stride(from: 1, to: 100, by: 2)))
        state.showMore()
        #expect(state.visibleIndices(categories: categories).count == 75)
        #expect(state.isExpanded(id: "failed", failed: true))
        state.toggle(id: "failed", failed: true)
        state.select(.git)
        #expect(!state.isExpanded(id: "failed", failed: true))
        #expect(state.visibleLimit == 50)
        #expect(categories.filter { $0 == .git }.count + categories.filter { $0 == .other }.count == 151)
    }
}
