/// Ephemeral navigation keyed by canonical command ID, owned by one session/turn card.
struct ExpandedTurnCommandNavigation {
    private(set) var selected: ExpandedTurnCommandCategory?
    private(set) var visibleLimit = 50
    private var disclosure: [String: Bool] = [:]

    mutating func select(_ category: ExpandedTurnCommandCategory?) {
        selected = category
        visibleLimit = 50
    }

    mutating func showMore() { visibleLimit += 50 }

    func isExpanded(id: String, failed: Bool) -> Bool { disclosure[id] ?? failed }

    mutating func toggle(id: String, failed: Bool) {
        disclosure[id] = !isExpanded(id: id, failed: failed)
    }

    func visibleIndices(categories: [ExpandedTurnCommandCategory]) -> [Int] {
        Array(categories.indices.lazy.filter { selected == nil || categories[$0] == selected }.prefix(visibleLimit))
    }
}
