import AppKit
import WebKit

@MainActor
final class BrowserInspectorProbe: NSObject {
    enum HideBehavior {
        case unsupported
        case noEffect
        case hides
    }

    private(set) var attachCount = 0
    private(set) var showCount = 0
    private(set) var hideCount = 0
    private(set) var closeCount = 0
    private let hideBehavior: HideBehavior
    private var visible = false
    private var attached = false
    private weak var frontendWebView: WKWebView?

    init(hideBehavior: HideBehavior = .unsupported) {
        self.hideBehavior = hideBehavior
        super.init()
    }

    override func responds(to aSelector: Selector!) -> Bool {
        guard NSStringFromSelector(aSelector) == "hide" else {
            return super.responds(to: aSelector)
        }
        return hideBehavior != .unsupported
    }

    @objc func isVisible() -> Bool {
        visible
    }

    @objc func isAttached() -> Bool {
        attached
    }

    @objc func attach() {
        attachCount += 1
        attached = true
        show()
    }

    @objc func show() {
        showCount += 1
        visible = true
    }

    @objc func hide() {
        hideCount += 1
        guard hideBehavior == .hides else { return }
        visible = false
    }

    @objc func close() {
        closeCount += 1
        visible = false
        attached = false
    }

    @objc func inspectorWebView() -> WKWebView? {
        frontendWebView
    }

    func setFrontendWebView(_ webView: WKWebView?) {
        frontendWebView = webView
    }
}
