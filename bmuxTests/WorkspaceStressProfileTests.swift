import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite(.serialized)
@MainActor
struct WorkspaceStressProfileTests {
    private struct TimedSample {
        let label: String
        let elapsedMs: Double
    }

    private struct TimingSummary {
        let count: Int
        let averageMs: Double
        let medianMs: Double
        let p95Ms: Double
        let maxMs: Double
        let totalMs: Double

        init(samples: [TimedSample]) {
            let sorted = samples.map(\.elapsedMs).sorted()
            count = sorted.count
            totalMs = sorted.reduce(0, +)
            averageMs = count > 0 ? totalMs / Double(count) : 0
            medianMs = Self.percentile(0.50, in: sorted)
            p95Ms = Self.percentile(0.95, in: sorted)
            maxMs = sorted.last ?? 0
        }

        private static func percentile(_ percentile: Double, in sortedValues: [Double]) -> Double {
            guard !sortedValues.isEmpty else { return 0 }
            let clamped = min(max(percentile, 0), 1)
            let index = Int((Double(sortedValues.count - 1) * clamped).rounded(.up))
            return sortedValues[min(sortedValues.count - 1, max(0, index))]
        }
    }

    @Test
    func testWorkspaceCreationAndSwitchingStressProfile() async throws {
        let config = WorkspaceStressProfileConfiguration.current()
        var creationSamples: [TimedSample] = []
        var populationSamples: [TimedSample] = []
        var switchSamples: [TimedSample] = []
        var switchDispatchSamples: [TimedSample] = []
        var switchFirstDrainSamples: [TimedSample] = []
        var switchUnfocusSamples: [TimedSample] = []
        var switchSecondDrainSamples: [TimedSample] = []

        let manager = timed("workspace-000-create", collectInto: &creationSamples) {
            TabManager(autoWelcomeIfNeeded: false)
        }

        defer { close(manager) }
        let bootstrapWorkspace = try #require(manager.selectedWorkspace)

        timed("workspace-000-populate", collectInto: &populationSamples) {
            populate(workspace: bootstrapWorkspace, tabsPerWorkspace: config.tabsPerWorkspace)
        }
        try await settleWorkspaceSelection(manager)

        for workspaceIndex in 1..<config.workspaceCount {
            let workspace = timed("workspace-\(label(for: workspaceIndex))-create", collectInto: &creationSamples) {
                manager.addWorkspace(
                    select: true,
                    eagerLoadTerminal: false,
                    autoWelcomeIfNeeded: false
                )
            }

            try await settleWorkspaceSelection(manager)

            timed("workspace-\(label(for: workspaceIndex))-populate", collectInto: &populationSamples) {
                populate(workspace: workspace, tabsPerWorkspace: config.tabsPerWorkspace)
            }
            try await settleWorkspaceSelection(manager)
        }

        #expect(manager.tabs.count == config.workspaceCount)
        #expect(manager.tabs.allSatisfy { $0.panels.count == config.tabsPerWorkspace })

        for pass in 0..<config.switchPasses {
            for switchIndex in 0..<manager.tabs.count {
                try await timedAsync("pass-\(label(for: pass))-next-\(label(for: switchIndex))", collectInto: &switchSamples) {
                    timed("pass-\(label(for: pass))-next-dispatch-\(label(for: switchIndex))", collectInto: &switchDispatchSamples) {
                        manager.selectNextTab()
                    }
                    try await timedAsync("pass-\(label(for: pass))-next-drain1-\(label(for: switchIndex))", collectInto: &switchFirstDrainSamples) {
                        try await WorkspaceStressQueueDelivery().wait()
                    }
                    timed("pass-\(label(for: pass))-next-unfocus-\(label(for: switchIndex))", collectInto: &switchUnfocusSamples) {
                        manager.completePendingWorkspaceUnfocus(reason: "workspace_stress_profile")
                    }
                    try await timedAsync("pass-\(label(for: pass))-next-drain2-\(label(for: switchIndex))", collectInto: &switchSecondDrainSamples) {
                        try await WorkspaceStressQueueDelivery().wait()
                    }
                }
            }

            for switchIndex in 0..<manager.tabs.count {
                try await timedAsync("pass-\(label(for: pass))-prev-\(label(for: switchIndex))", collectInto: &switchSamples) {
                    timed("pass-\(label(for: pass))-prev-dispatch-\(label(for: switchIndex))", collectInto: &switchDispatchSamples) {
                        manager.selectPreviousTab()
                    }
                    try await timedAsync("pass-\(label(for: pass))-prev-drain1-\(label(for: switchIndex))", collectInto: &switchFirstDrainSamples) {
                        try await WorkspaceStressQueueDelivery().wait()
                    }
                    timed("pass-\(label(for: pass))-prev-unfocus-\(label(for: switchIndex))", collectInto: &switchUnfocusSamples) {
                        manager.completePendingWorkspaceUnfocus(reason: "workspace_stress_profile")
                    }
                    try await timedAsync("pass-\(label(for: pass))-prev-drain2-\(label(for: switchIndex))", collectInto: &switchSecondDrainSamples) {
                        try await WorkspaceStressQueueDelivery().wait()
                    }
                }
            }
        }

        #expect(manager.selectedWorkspace != nil)

        let creationSummary = TimingSummary(samples: creationSamples)
        let populationSummary = TimingSummary(samples: populationSamples)
        let switchSummary = TimingSummary(samples: switchSamples)
        let switchDispatchSummary = TimingSummary(samples: switchDispatchSamples)
        let switchFirstDrainSummary = TimingSummary(samples: switchFirstDrainSamples)
        let switchUnfocusSummary = TimingSummary(samples: switchUnfocusSamples)
        let switchSecondDrainSummary = TimingSummary(samples: switchSecondDrainSamples)

        let report = [
            "Workspace stress config workspaces=\(config.workspaceCount) tabsPerWorkspace=\(config.tabsPerWorkspace) switchPasses=\(config.switchPasses)",
            reportLine(title: "create", summary: creationSummary, slowest: slowest(creationSamples)),
            reportLine(title: "populate", summary: populationSummary, slowest: slowest(populationSamples)),
            reportLine(title: "switch", summary: switchSummary, slowest: slowest(switchSamples)),
            reportLine(title: "switch.dispatch", summary: switchDispatchSummary, slowest: slowest(switchDispatchSamples)),
            reportLine(title: "switch.drain1", summary: switchFirstDrainSummary, slowest: slowest(switchFirstDrainSamples)),
            reportLine(title: "switch.unfocus", summary: switchUnfocusSummary, slowest: slowest(switchUnfocusSamples)),
            reportLine(title: "switch.drain2", summary: switchSecondDrainSummary, slowest: slowest(switchSecondDrainSamples))
        ].joined(separator: "\n")

        print(report)
        Attachment.record(report, named: "workspace-stress-profile.txt")

        if let createP95BudgetMs = config.createP95BudgetMs {
            #expect(creationSummary.p95Ms <= createP95BudgetMs,
                    "Workspace creation p95 exceeded budget")
        }
        if let switchP95BudgetMs = config.switchP95BudgetMs {
            #expect(switchSummary.p95Ms <= switchP95BudgetMs,
                    "Workspace switch p95 exceeded budget")
        }
    }

    @Test
    func testWorkspaceBatchActionsStressProfile() {
        let config = WorkspaceStressProfileConfiguration.current()
        let manager = TabManager(autoWelcomeIfNeeded: false)
        defer { close(manager) }
        for workspaceIndex in 1..<config.workspaceCount {
            _ = manager.addWorkspace(
                title: "Workspace \(label(for: workspaceIndex))",
                select: false,
                eagerLoadTerminal: false,
                autoWelcomeIfNeeded: false
            )
        }

        let workspaceIds = manager.tabs.map(\.id)
        let anchorWorkspaceId = workspaceIds[0]
        var colorSamples: [TimedSample] = []
        var scrollBarSamples: [TimedSample] = []
        var pinSamples: [TimedSample] = []
        var unpinSamples: [TimedSample] = []

        for pass in 0..<config.switchPasses {
            timed("pass-\(label(for: pass))-color-apply", collectInto: &colorSamples) {
                manager.applyWorkspaceColor("#1565C0", toWorkspaceIds: workspaceIds)
            }
            #expect(manager.tabs.allSatisfy { $0.customColor == "#1565C0" })
            timed("pass-\(label(for: pass))-color-clear", collectInto: &colorSamples) {
                manager.applyWorkspaceColor(nil, toWorkspaceIds: workspaceIds)
            }
            #expect(manager.tabs.allSatisfy { $0.customColor == nil })
            timed("pass-\(label(for: pass))-scrollbar-hide", collectInto: &scrollBarSamples) {
                manager.setWorkspaceTerminalScrollBarHidden(hidden: true, forWorkspaceIds: workspaceIds)
            }
            #expect(manager.tabs.allSatisfy { $0.terminalScrollBarHidden })
            timed("pass-\(label(for: pass))-scrollbar-show", collectInto: &scrollBarSamples) {
                manager.setWorkspaceTerminalScrollBarHidden(hidden: false, forWorkspaceIds: workspaceIds)
            }
            #expect(manager.tabs.allSatisfy { !$0.terminalScrollBarHidden })
            let pinResult = timed("pass-\(label(for: pass))-pin", collectInto: &pinSamples) {
                WorkspaceActionDispatcher.performPinAction(
                    WorkspaceActionDispatcher.PinState(
                        targetWorkspaceIds: workspaceIds,
                        anchorWorkspaceId: anchorWorkspaceId,
                        pinned: true
                    ),
                    in: manager
                )
            }
            #expect(!pinResult.changedWorkspaceIds.isEmpty)
            #expect(manager.tabs.allSatisfy { $0.isPinned })
            let unpinResult = timed("pass-\(label(for: pass))-unpin", collectInto: &unpinSamples) {
                WorkspaceActionDispatcher.performPinAction(
                    WorkspaceActionDispatcher.PinState(
                        targetWorkspaceIds: workspaceIds,
                        anchorWorkspaceId: anchorWorkspaceId,
                        pinned: false
                    ),
                    in: manager
                )
            }
            #expect(!unpinResult.changedWorkspaceIds.isEmpty)
            #expect(manager.tabs.allSatisfy { !$0.isPinned })
        }

        #expect(manager.tabs.count == config.workspaceCount)
        #expect(manager.tabs.allSatisfy { !$0.isPinned })
        #expect(manager.tabs.allSatisfy { $0.customColor == nil })
        #expect(manager.tabs.allSatisfy { !$0.terminalScrollBarHidden })

        let report = [
            "Workspace batch action stress config workspaces=\(config.workspaceCount) passes=\(config.switchPasses)",
            reportLine(title: "color", summary: TimingSummary(samples: colorSamples), slowest: slowest(colorSamples)),
            reportLine(title: "scrollbar", summary: TimingSummary(samples: scrollBarSamples), slowest: slowest(scrollBarSamples)),
            reportLine(title: "pin", summary: TimingSummary(samples: pinSamples), slowest: slowest(pinSamples)),
            reportLine(title: "unpin", summary: TimingSummary(samples: unpinSamples), slowest: slowest(unpinSamples))
        ].joined(separator: "\n")

        print(report)
        Attachment.record(report, named: "workspace-batch-actions-stress-profile.txt")
    }

    private func populate(workspace: Workspace, tabsPerWorkspace: Int) {
        guard tabsPerWorkspace > 0 else { return }
        while workspace.panels.count < tabsPerWorkspace {
            let created = workspace.newTerminalSurfaceInFocusedPane(focus: false)
            guard created != nil else {
                Issue.record("Expected terminal tab creation to succeed")
                return
            }
        }
    }

    private func close(_ manager: TabManager) {
        for workspace in manager.tabs {
            workspace.teardownRemoteConnection()
            workspace.teardownAllPanels()
        }
    }

    private func settleWorkspaceSelection(_ manager: TabManager) async throws {
        try await WorkspaceStressQueueDelivery().wait()
        manager.completePendingWorkspaceUnfocus(reason: "workspace_stress_profile")
        try await WorkspaceStressQueueDelivery().wait()
    }

    private func timedAsync(
        _ label: String,
        collectInto samples: inout [TimedSample],
        operation: () async throws -> Void
    ) async throws {
        let startedAt = ProcessInfo.processInfo.systemUptime
        try await operation()
        samples.append(TimedSample(label: label,
            elapsedMs: (ProcessInfo.processInfo.systemUptime - startedAt) * 1000))
    }

    @discardableResult
    private func timed<T>(
        _ label: String,
        collectInto samples: inout [TimedSample],
        operation: () -> T
    ) -> T {
        let startedAt = ProcessInfo.processInfo.systemUptime
        let value = operation()
        let elapsedMs = (ProcessInfo.processInfo.systemUptime - startedAt) * 1000.0
        samples.append(TimedSample(label: label, elapsedMs: elapsedMs))
        return value
    }

    private func slowest(_ samples: [TimedSample], count: Int = 5) -> String {
        samples
            .sorted { lhs, rhs in
                if lhs.elapsedMs == rhs.elapsedMs {
                    return lhs.label < rhs.label
                }
                return lhs.elapsedMs > rhs.elapsedMs
            }
            .prefix(count)
            .map { "\($0.label)=\(formatMs($0.elapsedMs))" }
            .joined(separator: ", ")
    }

    private func reportLine(title: String, summary: TimingSummary, slowest: String) -> String {
        [
            "\(title):",
            "count=\(summary.count)",
            "avg=\(formatMs(summary.averageMs))",
            "median=\(formatMs(summary.medianMs))",
            "p95=\(formatMs(summary.p95Ms))",
            "max=\(formatMs(summary.maxMs))",
            "total=\(formatMs(summary.totalMs))",
            "slowest=[\(slowest)]"
        ].joined(separator: " ")
    }

    private func formatMs(_ value: Double) -> String {
        String(format: "%.2fms", value)
    }

    private func label(for index: Int) -> String {
        String(format: "%03d", index)
    }
}
