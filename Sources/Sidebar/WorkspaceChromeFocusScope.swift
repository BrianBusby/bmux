import AppKit
import SwiftUI

/// Gives workspace chrome controls an exact native focus boundary without changing their actions.
///
/// The host survives projection updates. Forward the inherited environment as a
/// value, including read-only accessibility settings, across the hosting boundary.
@MainActor
struct WorkspaceChromeFocusScope<Content: View>: NSViewRepresentable {
    let usesIntrinsicSize: Bool
    var expandsToProposedWidth = false
    let onAttachmentChange: @MainActor (NSView, Bool) -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.self) private var environment

    private var rootView: some View { content().environment(\.self, environment) }

    func makeNSView(context: Context) -> WorkspaceChromeHostingView<AnyView> {
        let host = WorkspaceChromeHostingView(rootView: AnyView(rootView))
        host.sizingOptions = usesIntrinsicSize ? [.intrinsicContentSize] : []
        host.onAttachmentChange = onAttachmentChange
        host.isFocusScopeEnabled = environment.isEnabled
        return host
    }

    func updateNSView(_ host: WorkspaceChromeHostingView<AnyView>, context: Context) {
        host.isFocusScopeEnabled = environment.isEnabled
        host.rootView = AnyView(rootView)
        host.onAttachmentChange = onAttachmentChange
        if host.window != nil { onAttachmentChange(host, environment.isEnabled) }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: WorkspaceChromeHostingView<AnyView>, context: Context) -> CGSize? {
        if usesIntrinsicSize {
            let fitting = nsView.fittingSize
            return CGSize(width: expandsToProposedWidth ? proposal.width ?? fitting.width : fitting.width, height: fitting.height)
        }
        return proposal.replacingUnspecifiedDimensions()
    }

    static func dismantleNSView(_ host: WorkspaceChromeHostingView<AnyView>, coordinator: ()) {
        host.onAttachmentChange?(host, false)
        host.onAttachmentChange = nil
    }
}
