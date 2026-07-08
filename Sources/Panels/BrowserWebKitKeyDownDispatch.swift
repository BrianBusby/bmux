import AppKit

@MainActor
private var bmuxBrowserWebKitKeyDownDispatchDepth = 0

@MainActor
func bmuxBrowserWebKitKeyDownDispatchIsActive() -> Bool {
    bmuxBrowserWebKitKeyDownDispatchDepth > 0
}

@MainActor
func bmuxWithBrowserWebKitKeyDownDispatch<T>(_ body: () -> T) -> T {
    bmuxBrowserWebKitKeyDownDispatchDepth += 1
    defer {
        bmuxBrowserWebKitKeyDownDispatchDepth = max(0, bmuxBrowserWebKitKeyDownDispatchDepth - 1)
    }
    return body()
}

@MainActor
extension BmuxWebView {
    func forwardKeyDownToWebKit(_ event: NSEvent) {
        bmuxWithBrowserWebKitKeyDownDispatch {
            super.keyDown(with: event)
        }
    }
}
