import SwiftUI

struct SidebarWorkspaceFrameAnchorModifier: ViewModifier {
    let id: UUID
    let isEnabled: Bool

    func body(content: Content) -> some View {
        // Branchless: always apply anchorPreference, emit [:] when disabled. An
        // if/else gives `content` distinct identity per state, so flipping
        // isEnabled at drag start/end recreated every visible row's subtree
        // (lost @State, fresh snapshot builds + relayout mid-drag). The frame
        // *reader* stays gated on the drag (#5325), so an empty emit costs nothing.
        content.anchorPreference(key: SidebarWorkspaceRowFramePreferenceKey.self, value: .bounds) { anchor in
            isEnabled ? [id: anchor] : [:]
        }
    }
}

extension View {
    func sidebarWorkspaceFrameAnchor(id: UUID, isEnabled: Bool) -> some View {
        modifier(SidebarWorkspaceFrameAnchorModifier(id: id, isEnabled: isEnabled))
    }
}

struct SidebarWorkspaceRowFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: Anchor<CGRect>] = [:]

    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, next in next }
    }
}

struct SelectedWorkspaceRowFrameAnchorModifier: ViewModifier {
    let id: UUID
    let isSelected: Bool

    func body(content: Content) -> some View {
        content.anchorPreference(key: SelectedWorkspaceRowFramePreferenceKey.self, value: .bounds) { anchor in
            isSelected ? [id: anchor] : [:]
        }
    }
}

extension View {
    func selectedWorkspaceFrameAnchor(id: UUID, isSelected: Bool) -> some View {
        modifier(SelectedWorkspaceRowFrameAnchorModifier(id: id, isSelected: isSelected))
    }
}

struct SelectedWorkspaceRowFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: Anchor<CGRect>] = [:]

    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, next in next }
    }
}
