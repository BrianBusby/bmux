import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite struct SavedLayoutDefinitionTests {
    @Test func savedLayoutCodableRoundTripsNestedSplitTree() throws {
        let layout = BmuxSavedLayout(
            name: "Nested",
            description: "Round trip",
            workspace: BmuxWorkspaceDefinition(
                name: "Workspace",
                cwd: "/tmp/project",
                color: "#123456",
                env: ["A": "B"],
                layout: Self.nestedLayout
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(layout)
        let decoded = try JSONDecoder().decode(BmuxSavedLayout.self, from: data)

        #expect(decoded.name == "Nested")
        #expect(decoded.description == "Round trip")
        #expect(decoded.workspace.cwd == "/tmp/project")
        let root = try #require(decoded.workspace.layout)
        guard case .split(let split) = root else {
            Issue.record("Expected split root")
            return
        }
        #expect(split.direction == .horizontal)
        #expect(split.split == 0.33)
        guard case .pane(let firstPane) = split.children[0] else {
            Issue.record("Expected first pane")
            return
        }
        #expect(firstPane.surfaces[0].type == .terminal)
        #expect(firstPane.surfaces[0].cwd == "server")
        #expect(firstPane.surfaces[0].name == "Server")
        #expect(firstPane.surfaces[0].focus == true)
    }

    @Test func splitDefinitionClampsDividerPosition() {
        #expect(BmuxSplitDefinition(direction: .horizontal, split: -1, children: Self.twoPanes).clampedSplitPosition == 0.1)
        #expect(BmuxSplitDefinition(direction: .horizontal, split: 2, children: Self.twoPanes).clampedSplitPosition == 0.9)
        #expect(BmuxSplitDefinition(direction: .horizontal, split: 0.42, children: Self.twoPanes).clampedSplitPosition == 0.42)
        #expect(BmuxSplitDefinition(direction: .horizontal, children: Self.twoPanes).clampedSplitPosition == 0.5)
    }

    @Test func storeJSONLayoutDecodesThroughWorkspaceCreateLayoutDecoder() throws {
        let context = try TemporarySavedLayoutContext()
        defer { context.cleanup() }
        let store = SavedLayoutStore(fileURL: context.fileURL)
        try store.save(
            BmuxSavedLayout(
                name: "Nested",
                description: nil,
                workspace: BmuxWorkspaceDefinition(cwd: "/tmp/project", layout: Self.nestedLayout)
            ),
            overwrite: false
        )

        let data = try Data(contentsOf: context.fileURL)
        let decoded = try JSONDecoder().decode(SavedLayoutStore.LayoutsFile.self, from: data)
        let layoutNode = try #require(decoded.layouts.first?.workspace.layout)
        let layoutData = try JSONEncoder().encode(layoutNode)
        _ = try JSONDecoder().decode(BmuxLayoutNode.self, from: layoutData)
    }

    private static var nestedLayout: BmuxLayoutNode {
        .split(
            BmuxSplitDefinition(
                direction: .horizontal,
                split: 0.33,
                children: [
                    .pane(BmuxPaneDefinition(surfaces: [
                        BmuxSurfaceDefinition(type: .terminal, name: "Server", command: nil, cwd: "server", env: nil, url: nil, focus: true),
                    ])),
                    .split(BmuxSplitDefinition(
                        direction: .vertical,
                        split: 0.66,
                        children: [
                            .pane(BmuxPaneDefinition(surfaces: [
                                BmuxSurfaceDefinition(type: .browser, name: "Docs", command: nil, cwd: nil, env: nil, url: "https://example.com", focus: nil),
                            ])),
                            .pane(BmuxPaneDefinition(surfaces: [
                                BmuxSurfaceDefinition(type: .terminal, name: nil, command: nil, cwd: nil, env: nil, url: nil, focus: nil),
                            ])),
                        ]
                    )),
                ]
            )
        )
    }

    private static var twoPanes: [BmuxLayoutNode] {
        [
            .pane(BmuxPaneDefinition(surfaces: [BmuxSurfaceDefinition(type: .terminal)])),
            .pane(BmuxPaneDefinition(surfaces: [BmuxSurfaceDefinition(type: .terminal)])),
        ]
    }
}
