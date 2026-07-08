import Foundation

/// Compression mode for agent terminal output stored under
/// `terminal.agentTokenOptimization.mode` in `~/.config/bmux/bmux.json`.
public enum AgentTokenOptimizationMode: String, CaseIterable, Sendable, SettingCodable {
    case off
    case conservative
    case balanced
    case aggressive
}
