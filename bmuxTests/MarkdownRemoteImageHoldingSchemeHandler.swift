import WebKit

@MainActor
final class MarkdownRemoteImageHoldingSchemeHandler: NSObject, WKURLSchemeHandler {
    private var tasks: [ObjectIdentifier: WKURLSchemeTask] = [:]

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        tasks[ObjectIdentifier(urlSchemeTask as AnyObject)] = urlSchemeTask
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        tasks[ObjectIdentifier(urlSchemeTask as AnyObject)] = nil
    }

    func cancelOpenTasks() {
        let openTasks = Array(tasks.values)
        tasks.removeAll()
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        for task in openTasks {
            task.didFailWithError(error)
        }
    }
}
