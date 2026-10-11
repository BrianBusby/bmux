import AppKit
import SwiftUI

/// Gives sidebar controls an exact native focus boundary without changing their actions.
///
/// The host survives projection updates. Forward the inherited environment as a
/// value, including read-only accessibility settings, across the hosting boundary.
@MainActor
struct WorkspaceSidebarFocusScope<Content: View>: NSViewRepresentable {
    let usesIntrinsicSize: Bool
    let onAttachmentChange: @MainActor (NSView, Bool) -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.self) private var environment

    private var rootView: some View { content().environment(\.self, environment) }

    func makeNSView(context: Context) -> WorkspaceSidebarHostingView<AnyView> {
        let host = WorkspaceSidebarHostingView(rootView: AnyView(rootView))
        host.sizingOptions = usesIntrinsicSize ? [.intrinsicContentSize] : []
        host.onAttachmentChange = onAttachmentChange
        host.isFocusScopeEnabled = environment.isEnabled
        return host
    }

    func updateNSView(_ host: WorkspaceSidebarHostingView<AnyView>, context: Context) {
        host.isFocusScopeEnabled = environment.isEnabled
        host.rootView = AnyView(rootView)
        host.onAttachmentChange = onAttachmentChange
        if host.window != nil { onAttachmentChange(host, environment.isEnabled) }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: WorkspaceSidebarHostingView<AnyView>, context: Context) -> CGSize? {
        if usesIntrinsicSize { return nsView.fittingSize }
        return proposal.replacingUnspecifiedDimensions()
    }

    static func dismantleNSView(_ host: WorkspaceSidebarHostingView<AnyView>, coordinator: ()) {
        host.onAttachmentChange?(host, false)
        host.onAttachmentChange = nil
    }
}
