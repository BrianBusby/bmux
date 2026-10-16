import Foundation

struct WorkspaceStressProfileConfiguration {
    let workspaceCount: Int
    let tabsPerWorkspace: Int
    let switchPasses: Int
    let createP95BudgetMs: Double?
    let switchP95BudgetMs: Double?

    static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> WorkspaceStressProfileConfiguration {
        WorkspaceStressProfileConfiguration(
            workspaceCount: parseInt(environment["BMUX_WORKSPACE_STRESS_WORKSPACES"], default: 48, minimum: 2),
            tabsPerWorkspace: parseInt(environment["BMUX_WORKSPACE_STRESS_TABS_PER_WORKSPACE"], default: 10, minimum: 1),
            switchPasses: parseInt(environment["BMUX_WORKSPACE_STRESS_SWITCH_PASSES"], default: 6, minimum: 1),
            createP95BudgetMs: parseDouble(environment["BMUX_WORKSPACE_STRESS_CREATE_P95_BUDGET_MS"]),
            switchP95BudgetMs: parseDouble(environment["BMUX_WORKSPACE_STRESS_SWITCH_P95_BUDGET_MS"])
        )
    }

    private static func parseInt(_ value: String?, default defaultValue: Int, minimum: Int) -> Int {
        guard let value, let parsed = Int(value) else { return defaultValue }
        return max(minimum, parsed)
    }

    private static func parseDouble(_ value: String?) -> Double? {
        guard let value, let parsed = Double(value) else { return nil }
        return parsed
    }
}
