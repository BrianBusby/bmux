import AppKit
import WebKit

extension WebViewRepresentable {
    static func directTransferChild(of container: NSView, containing descendant: NSView) -> NSView? {
        var current: NSView? = descendant
        var directChild: NSView?
        while let view = current, view !== container {
            directChild = view
            current = view.superview
        }
        guard current === container else { return nil }
        return directChild
    }

    static func relatedWebKitTransferSubviews(
        from sourceSuperview: NSView,
        primaryWebView: WKWebView
    ) -> [NSView] {
        var relatedSubviews: [NSView] = []
        var seen = Set<ObjectIdentifier>()
        func append(_ candidate: NSView?) {
            guard let candidate, candidate !== sourceSuperview else { return }
            let id = ObjectIdentifier(candidate)
            guard seen.insert(id).inserted else { return }
            relatedSubviews.append(candidate)
        }

        if let directChild = directTransferChild(of: sourceSuperview, containing: primaryWebView) {
            if let inspectorFrontendWebView = primaryWebView.bmuxInspectorFrontendWebView(),
               inspectorFrontendWebView === directChild || inspectorFrontendWebView.isDescendant(of: directChild) {
                append(primaryWebView)
            } else {
                append(directChild)
            }
        } else {
            append(primaryWebView)
        }

        let inspectorFrontendWebView = primaryWebView.bmuxInspectorFrontendWebView()
        let sourceIsManagedLocalSlot = sourceSuperview is WindowBrowserSlotView
        for view in sourceSuperview.subviews {
            if view === primaryWebView { continue }
            if !sourceIsManagedLocalSlot,
               let inspectorFrontendWebView,
               inspectorFrontendWebView === view || inspectorFrontendWebView.isDescendant(of: view) {
                continue
            }
            let className = String(describing: type(of: view))
            if !sourceIsManagedLocalSlot,
               bmuxIsWebInspectorClassName(className) || bmuxIsWebInspectorObject(view) {
                continue
            }
            let isTransferableInspectorCompanion =
                sourceIsManagedLocalSlot &&
                (
                    bmuxIsWebInspectorClassName(className) ||
                    bmuxIsWebInspectorObject(view) ||
                    inspectorFrontendWebView.map { $0 === view || $0.isDescendant(of: view) } == true
                )
            guard className.contains("WK") || isTransferableInspectorCompanion else { continue }
            append(view)
        }

        return relatedSubviews
    }

    static func moveWebKitRelatedSubviewsIntoHostIfNeeded(
        from sourceSuperview: NSView,
        to container: WindowBrowserSlotView,
        primaryWebView: WKWebView,
        reason: String
    ) {
        let relatedSubviews = relatedWebKitTransferSubviews(
            from: sourceSuperview,
            primaryWebView: primaryWebView
        )
        guard !relatedSubviews.isEmpty else { return }
        let preserveSlotLocalFrames = sourceSuperview is WindowBrowserSlotView
        let sourceSlotBoundsSize = sourceSuperview.bounds.size
        var movedSubviewCount = 0
        var reusedSourceLocalFrames = false
#if DEBUG
        bmuxDebugLog(
            "browser.localHost.reparent.batch reason=\(reason) source=\(transferObjectID(sourceSuperview)) " +
            "container=\(transferObjectID(container)) count=\(relatedSubviews.count) " +
            "sourceType=\(String(describing: type(of: sourceSuperview))) targetType=\(String(describing: type(of: container)))"
        )
#endif
        for view in relatedSubviews {
            if view === container || view.isDescendant(of: container) { continue }
            let className = String(describing: type(of: view))
            let targetFrame: NSRect
            let currentSuperview = view.superview
            if preserveSlotLocalFrames && currentSuperview === sourceSuperview {
                targetFrame = view.frame
                reusedSourceLocalFrames = true
            } else {
                let frameInWindow = currentSuperview?.convert(view.frame, to: nil)
                    ?? sourceSuperview.convert(view.frame, to: nil)
                targetFrame = container.convert(frameInWindow, from: nil)
            }
            view.removeFromSuperview()
            container.addSubview(view, positioned: .above, relativeTo: nil)
            view.frame = targetFrame
            movedSubviewCount += 1
#if DEBUG
            bmuxDebugLog(
                "browser.localHost.reparent.batch.item reason=\(reason) class=\(className) " +
                "view=\(transferObjectID(view))"
            )
#endif
        }
        guard movedSubviewCount > 0 else { return }
        if reusedSourceLocalFrames, sourceSlotBoundsSize != container.bounds.size {
            container.resizeSubviews(withOldSize: sourceSlotBoundsSize)
            container.needsLayout = true
            container.layoutSubtreeIfNeeded()
        }
    }

    private static func transferObjectID(_ object: AnyObject?) -> String {
        guard let object else { return "nil" }
        return String(describing: Unmanaged.passUnretained(object).toOpaque())
    }
}
