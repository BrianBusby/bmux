import Foundation

extension BMUXCLI {
    func runHooksSocketCommand(
        commandArgs: [String],
        client: SocketClient,
        telemetry: CLISocketSentryTelemetry,
        socketPassword: String? = nil
    ) async throws {
        guard let first = commandArgs.first?.lowercased() else {
            throw CLIError(message: "Usage: bmux hooks <setup|uninstall|feed|claude|agent>")
        }
        let rest = Array(commandArgs.dropFirst())
        guard connectedCodexHookBindingIsCurrent(client: client, environment: ProcessInfo.processInfo.environment) else {
            telemetry.breadcrumb("hooks.connected-codex.binding-unavailable")
            print("{}")
            return
        }

        switch first {
        case "setup", "install", "uninstall":
            throw CLIError(message: "hooks \(first) must be handled before socket dispatch")

        case "feed":
            telemetry.breadcrumb("hooks.feed.dispatch")
            do {
                try runFeedHook(commandArgs: rest, client: client, telemetry: telemetry)
                telemetry.breadcrumb("hooks.feed.completed")
            } catch {
                telemetry.breadcrumb("hooks.feed.failure")
                captureSocketTransportError(telemetry: telemetry, stage: "hooks_feed_dispatch", error: error, client: client)
                throw error
            }

        case "claude":
            telemetry.breadcrumb("hooks.claude.dispatch")
            do {
                try runClaudeHook(commandArgs: rest, client: client, telemetry: telemetry, socketPassword: socketPassword)
                telemetry.breadcrumb("hooks.claude.completed")
            } catch {
                telemetry.breadcrumb("hooks.claude.failure")
                captureSocketTransportError(telemetry: telemetry, stage: "hooks_claude_dispatch", error: error, client: client)
                throw error
            }

        default:
            guard let def = Self.agentDef(named: first) else {
                throw CLIError(message: "Unknown hooks target: \(first)")
            }
            telemetry.breadcrumb("hooks.\(def.name).dispatch")
            do {
                try await runGenericAgentHook(def: def, commandArgs: rest, client: client, telemetry: telemetry, socketPassword: socketPassword)
                telemetry.breadcrumb("hooks.\(def.name).completed")
            } catch {
                telemetry.breadcrumb("hooks.\(def.name).failure")
                captureSocketTransportError(telemetry: telemetry, stage: "hooks_\(def.name)_dispatch", error: error, client: client)
                throw error
            }
        }
    }
}
