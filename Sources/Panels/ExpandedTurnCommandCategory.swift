/// Every recorded command has exactly one display category.
enum ExpandedTurnCommandCategory: String, CaseIterable, Equatable {
    case git, read, edit, build, bmux, other
}
