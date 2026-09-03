import Foundation

extension WorkProvenanceRuntime {
    static func shouldStartInCurrentProcess(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        !AppDelegate.detectRunningUnderXCTest(environment) ||
            environment["BMUX_ENABLE_PROVENANCE_RUNTIME_IN_XCTEST"] == "1"
    }
}
