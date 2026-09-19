import Foundation

extension TerminalPanel {
    enum PromptNavigationTarget: Equatable {
        case bookmark(Int)
        case currentPrompt
    }

    struct PromptNavigationBookmark: Equatable {
        private static let maxMessageLength = 1_000

        var row: Int
        var message: String?

        init(row: Int, message: String? = nil) {
            self.row = max(0, row)
            self.message = Self.normalizedMessage(message)
        }

        init(snapshot: SessionPromptNavigationBookmarkSnapshot) {
            self.init(row: snapshot.row, message: snapshot.message)
        }

        var snapshot: SessionPromptNavigationBookmarkSnapshot {
            SessionPromptNavigationBookmarkSnapshot(row: row, message: message)
        }

        private static func normalizedMessage(_ message: String?) -> String? {
            guard let message else { return nil }
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return String(trimmed.prefix(maxMessageLength))
        }
    }

    func sessionPromptNavigationSnapshot() -> SessionPromptNavigationSnapshot? {
        let bookmarks = normalizedPromptNavigationBookmarks(promptNavigationBookmarks)
        guard !bookmarks.isEmpty else { return nil }
        let selectedIndex = promptNavigationSelectedIndex.flatMap { bookmarks.indices.contains($0) ? $0 : nil }
        return SessionPromptNavigationSnapshot(
            bookmarkRows: bookmarks.map(\.row),
            bookmarks: bookmarks.map(\.snapshot),
            selectedIndex: selectedIndex
        )
    }

    func restoreSessionPromptNavigationSnapshot(_ snapshot: SessionPromptNavigationSnapshot?) {
        let bookmarks = normalizedPromptNavigationBookmarks(
            snapshot?.effectiveBookmarks.map(PromptNavigationBookmark.init(snapshot:)) ?? []
        )
        promptNavigationBookmarks = bookmarks
        promptNavigationSelectedIndex = snapshot?.selectedIndex.flatMap { bookmarks.indices.contains($0) ? $0 : nil }
        publishPromptNavigationAvailability()
    }

    @discardableResult
    func recordPromptNavigationBookmark(message: String? = nil) -> Bool {
        guard let row = hostedView.currentPromptNavigationBookmarkRow(message: message) else { return false }
        return recordPromptNavigationBookmark(row: row, message: message)
    }

    @discardableResult
    func recordPromptNavigationBookmark(row: Int) -> Bool {
        recordPromptNavigationBookmark(row: row, message: nil)
    }

    @discardableResult
    func navigatePromptBookmark(delta: Int) -> Bool {
        navigatePromptBookmark(
            delta: delta,
            currentViewportReferenceRow: hostedView.currentPromptNavigationReferenceRow(delta: delta),
            scrollToCurrentPrompt: { [hostedView] in hostedView.scrollToPromptNavigationCurrentInput() },
            resolveBookmarkRow: { [hostedView] bookmark in
                hostedView.resolvedPromptNavigationBookmarkRow(message: bookmark.message, fallbackRow: bookmark.row)
            }
        ) { [hostedView] row in
            hostedView.scrollToPromptNavigationViewportRow(row)
        }
    }

    @discardableResult
    func navigatePromptBookmark(delta: Int, scrollToRow: (Int) -> Bool) -> Bool {
        navigatePromptBookmark(delta: delta, currentViewportReferenceRow: nil, scrollToCurrentPrompt: { true }, resolveBookmarkRow: { $0.row }, scrollToRow: scrollToRow)
    }

    @discardableResult
    func navigatePromptBookmark(
        delta: Int,
        currentViewportReferenceRow: Int? = nil,
        scrollToCurrentPrompt: () -> Bool,
        scrollToRow: (Int) -> Bool
    ) -> Bool {
        navigatePromptBookmark(delta: delta, currentViewportReferenceRow: currentViewportReferenceRow, scrollToCurrentPrompt: scrollToCurrentPrompt, resolveBookmarkRow: { $0.row }, scrollToRow: scrollToRow)
    }

    private func normalizedPromptNavigationBookmarks(_ bookmarks: [PromptNavigationBookmark]) -> [PromptNavigationBookmark] {
        let normalizedBookmarks = bookmarks.reduce(into: [PromptNavigationBookmark]()) { result, bookmark in
            let boundedBookmark = PromptNavigationBookmark(row: bookmark.row, message: bookmark.message)
            if let lastIndex = result.indices.last, result[lastIndex].row == boundedBookmark.row {
                if result[lastIndex].message == nil { result[lastIndex].message = boundedBookmark.message }
                return
            }
            result.append(boundedBookmark)
        }
        return Array(normalizedBookmarks.suffix(maxPromptNavigationBookmarks))
    }

    @discardableResult
    private func recordPromptNavigationBookmark(row: Int, message: String?) -> Bool {
        let boundedRow = max(0, row)
        let bookmark = PromptNavigationBookmark(row: boundedRow, message: message)
        guard promptNavigationBookmarks.last?.row != boundedRow else {
            if let lastIndex = promptNavigationBookmarks.indices.last, promptNavigationBookmarks[lastIndex].message == nil {
                promptNavigationBookmarks[lastIndex].message = bookmark.message
            }
            promptNavigationSelectedIndex = nil
            publishPromptNavigationAvailability()
            return false
        }
        promptNavigationBookmarks.append(bookmark)
        if promptNavigationBookmarks.count > maxPromptNavigationBookmarks {
            promptNavigationBookmarks.removeFirst(promptNavigationBookmarks.count - maxPromptNavigationBookmarks)
        }
        promptNavigationSelectedIndex = nil
        publishPromptNavigationAvailability()
        return true
    }

    @discardableResult
    private func navigatePromptBookmark(
        delta: Int,
        currentViewportReferenceRow: Int? = nil,
        scrollToCurrentPrompt: () -> Bool,
        resolveBookmarkRow: (PromptNavigationBookmark) -> Int,
        scrollToRow: (Int) -> Bool
    ) -> Bool {
        guard let target = promptNavigationTarget(delta: delta, currentViewportReferenceRow: currentViewportReferenceRow) else { return false }
        switch target {
        case .bookmark(let targetIndex):
            let bookmark = promptNavigationBookmarks[targetIndex]
            let row = max(0, resolveBookmarkRow(bookmark))
            guard scrollToRow(row) else { return false }
            if promptNavigationBookmarks.indices.contains(targetIndex), promptNavigationBookmarks[targetIndex].row != row {
                promptNavigationBookmarks[targetIndex].row = row
            }
            promptNavigationSelectedIndex = targetIndex
        case .currentPrompt:
            guard scrollToCurrentPrompt() else { return false }
            promptNavigationSelectedIndex = nil
            preferTextBoxInputWhenActivated()
            promptNavigationTextBoxPulseSeed &+= 1
        }
        publishPromptNavigationAvailability()
        return true
    }

    private func promptNavigationTarget(delta: Int, currentViewportReferenceRow: Int? = nil) -> PromptNavigationTarget? {
        guard delta != 0, !promptNavigationBookmarks.isEmpty else { return nil }
        let step = delta < 0 ? -1 : 1
        if promptNavigationSelectedIndex == nil, let currentViewportReferenceRow {
            if step < 0, let targetIndex = promptNavigationBookmarks.lastIndex(where: { $0.row < currentViewportReferenceRow }) { return .bookmark(targetIndex) }
            if step > 0, let targetIndex = promptNavigationBookmarks.firstIndex(where: { $0.row > currentViewportReferenceRow }) { return .bookmark(targetIndex) }
            if step > 0 { return .currentPrompt }
        }
        let targetIndex = (promptNavigationSelectedIndex ?? promptNavigationBookmarks.count) + step
        if promptNavigationBookmarks.indices.contains(targetIndex) { return .bookmark(targetIndex) }
        if promptNavigationSelectedIndex != nil, targetIndex == promptNavigationBookmarks.count { return .currentPrompt }
        return nil
    }

    private func publishPromptNavigationAvailability() {
        let hasBookmarks = !promptNavigationBookmarks.isEmpty
        let canMoveBackward = promptNavigationTarget(delta: -1) != nil
        let canMoveForward = promptNavigationTarget(delta: 1) != nil
        if promptNavigationHasBookmarks != hasBookmarks { promptNavigationHasBookmarks = hasBookmarks }
        if promptNavigationCanMoveBackward != canMoveBackward { promptNavigationCanMoveBackward = canMoveBackward }
        if promptNavigationCanMoveForward != canMoveForward { promptNavigationCanMoveForward = canMoveForward }
    }
}
