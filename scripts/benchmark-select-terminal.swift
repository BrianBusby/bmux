import ApplicationServices
import Foundation

/// Selects the real shell tab during benchmark setup, outside the measured event path.
@main
private struct BenchmarkTerminalSelection {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let checkingTrust = arguments == ["--check-trust"]
        let pid = arguments.count == 1 ? Int32(arguments[0]) : nil
        guard checkingTrust || (pid ?? 0) > 0 else {
            fail("Usage: benchmark-select-terminal <app-pid> | --check-trust")
        }
        guard AXIsProcessTrusted() else {
            fail("Accessibility trust is required to select Terminal for the benchmark.")
        }
        if checkingTrust { return }
        guard let pid else { fail("Missing benchmark app PID") }

        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 1)
        let deadline = Date().addingTimeInterval(8)
        repeat {
            if let value = attribute(application, kAXFocusedWindowAttribute),
               CFGetTypeID(value) == AXUIElementGetTypeID(),
               let button = terminalButton(in: unsafeBitCast(value, to: AXUIElement.self)) {
                let result = AXUIElementPerformAction(button, kAXPressAction as CFString)
                guard result == .success else {
                    fail("Terminal AXPress failed: \(result.rawValue)")
                }
                return
            }
            // The external app may still be mounting its accessibility tree after activation.
            Thread.sleep(forTimeInterval: 0.05)
        } while Date() < deadline
        fail("No Terminal button found in the target app's focused window; launch with English locale.")
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private static func terminalButton(in window: AXUIElement) -> AXUIElement? {
        var remaining = [window]
        var visited = 0
        while let element = remaining.popLast(), visited < 4_096 {
            visited += 1
            let role = attribute(element, kAXRoleAttribute) as? String
            let title = attribute(element, kAXTitleAttribute) as? String
            let description = attribute(element, kAXDescriptionAttribute) as? String
            if role == kAXButtonRole, title == "Terminal" || description == "Terminal" {
                return element
            }
            remaining.append(contentsOf: attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [])
        }
        return nil
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }
}
