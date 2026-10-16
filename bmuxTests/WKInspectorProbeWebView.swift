import AppKit
import WebKit

@MainActor
final class WKInspectorProbeWebView: WKWebView {
    private(set) var evaluatedJavaScript: [String] = []

    @MainActor override func evaluateJavaScript(
        _ javaScriptString: String,
        completionHandler: (@MainActor @Sendable (Any?, (any Error)?) -> Void)? = nil
    ) {
        evaluatedJavaScript.append(javaScriptString)
        completionHandler?(nil, nil)
    }
}
