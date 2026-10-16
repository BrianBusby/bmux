import BmuxCommandPalette
import Testing

@Suite struct CommandPaletteMetadataContractTests {
    @Test func directoryBranchAndPortMetadataRemainSearchable() {
        let metadata = CommandPaletteSwitcherSearchMetadata(
            directories: ["/Users/example/dev/bmuxterm-hq/worktrees/feat-cmd-palette"],
            branches: ["feature/cmd-palette-indexing"],
            ports: [3000, 9222]
        )
        let keywords = CommandPaletteSwitcherSearchIndexer(
            baseKeywords: ["workspace", "switch"], metadata: metadata
        ).keywords

        #expect(keywords.contains("/Users/example/dev/bmuxterm-hq/worktrees/feat-cmd-palette"))
        #expect(keywords.contains("feat-cmd-palette"))
        #expect(keywords.contains("feature/cmd-palette-indexing"))
        for component in ["feature", "cmd", "palette", "indexing"] {
            #expect(keywords.contains(component))
        }
        #expect(keywords.contains("3000"))
        #expect(keywords.contains(":9222"))
        #expect(CommandPaletteFuzzyMatcher.score(query: "cmd-palette-indexing", candidates: keywords) != nil)
    }
}
