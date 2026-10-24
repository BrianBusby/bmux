import Foundation
import Testing
@testable import BmuxWorkspacePersistence

@Suite
struct WorkspaceExplorerCloseJournalTests {
    @Test
    func twoWritersKeepTheLatestCloseAndClearOlderFiles() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-close-journal-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("provenance.sqlite")
        let first = WorkspaceExplorerCloseJournal(databaseURL: databaseURL, fileManager: FileManager())
        let second = WorkspaceExplorerCloseJournal(databaseURL: databaseURL, fileManager: FileManager())
        let stableID = UUID()
        let cutoff = Date(timeIntervalSince1970: 1_800_000_000)
        let later = cutoff.addingTimeInterval(1)

        try second.record(.init(stableID: stableID, title: "Cedar Street Roof Inspection",
            closedAt: later, colorHex: nil))
        try first.record(.init(stableID: stableID, title: "Maple Street Roof Inspection",
            closedAt: cutoff.addingTimeInterval(-1), colorHex: nil))
        #expect(try await first.candidates().map(\.title) == ["Cedar Street Roof Inspection"])

        try await first.clear(through: cutoff)
        #expect(try await second.candidates().map(\.closedAt) == [later])
    }
    @Test
    func closeRecordedAfterClearCannotRetainOlderIdentity() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-clear-journal-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("provenance.sqlite")
        let clearer = WorkspaceExplorerCloseJournal(databaseURL: databaseURL, fileManager: FileManager())
        let closer = WorkspaceExplorerCloseJournal(databaseURL: databaseURL, fileManager: FileManager())
        let clearedAt = Date(timeIntervalSince1970: 1_800_000_000)

        try await clearer.clear(through: clearedAt)
        try closer.record(.init(stableID: UUID(), title: "Maple Street Roof Inspection",
            closedAt: clearedAt.addingTimeInterval(-1), colorHex: nil))

        #expect(try await clearer.candidates().isEmpty)
        let journalDirectory = directory.appendingPathComponent("explorer-close-journal")
        let files = try FileManager.default.contentsOfDirectory(
            at: journalDirectory, includingPropertiesForKeys: nil
        )
        #expect(files.allSatisfy { $0.pathExtension != "json" })
    }

    @Test
    func readsPriorSingleFileJournalFormat() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-prior-journal-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let journalDirectory = directory.appendingPathComponent("explorer-close-journal")
        try FileManager.default.createDirectory(at: journalDirectory,
            withIntermediateDirectories: true)
        let stableID = UUID()
        let closedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let data = try JSONSerialization.data(withJSONObject: [
            "version": 1, "stableID": stableID.uuidString,
            "title": "Maple Street Roof Inspection",
            "closedAt": closedAt.timeIntervalSince1970,
        ])
        try data.write(to: journalDirectory.appendingPathComponent("\(stableID.uuidString).json"))

        let journal = WorkspaceExplorerCloseJournal(
            databaseURL: directory.appendingPathComponent("provenance.sqlite"),
            fileManager: FileManager()
        )
        let record = try #require(await journal.candidates().first)
        #expect(record.stableID == stableID)
        #expect(record.closedAt == closedAt)
        #expect(record.title == "Maple Street Roof Inspection")
    }

    @Test
    func repeatedClearsPruneOldMarkersWithoutRevealingOldCloses() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-repeated-clear-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = WorkspaceExplorerCloseJournal(
            databaseURL: directory.appendingPathComponent("provenance.sqlite"),
            fileManager: FileManager()
        )
        let cutoff = Date(timeIntervalSince1970: 1_800_000_000)
        for offset in 0..<5 {
            try await journal.clear(through: cutoff.addingTimeInterval(TimeInterval(offset)))
        }
        try await journal.clear(through: cutoff.addingTimeInterval(4))
        let journalDirectory = directory.appendingPathComponent("explorer-close-journal")
        let markers = try FileManager.default.contentsOfDirectory(
            at: journalDirectory, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "clear" }
        #expect(markers.count == 1)

        try journal.record(.init(stableID: UUID(), title: "Maple Street Roof Inspection",
            closedAt: cutoff.addingTimeInterval(3), colorHex: nil))
        #expect(try await journal.candidates().isEmpty)
    }

}
