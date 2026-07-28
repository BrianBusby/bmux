import Foundation

struct RepoAgentLauncherCommandCustomizer {
    struct LaunchCommand {
        let command: BmuxCommandDefinition
        let sourceCommandID: String
    }

    func agent(for command: BmuxCommandDefinition) -> BmuxConfigAgentKind? {
        guard let layout = command.workspace?.layout else { return nil }
        return firstAgent(in: layout)
    }

    func launchCommand(
        for action: BmuxResolvedConfigAction,
        commands: [BmuxCommandDefinition],
        parameters: [RepoAgentLauncherParameterSelection]
    ) -> LaunchCommand? {
        guard let commandName = action.workspaceCommandName,
              let command = commands.first(where: { $0.name == commandName }),
              let agent = agent(for: command) else {
            return nil
        }
        let parameterizedCommand: BmuxCommandDefinition
        if parameters.isEmpty {
            parameterizedCommand = command
        } else if let customizedCommand = self.command(byAppending: parameters, to: command, for: agent) {
            parameterizedCommand = customizedCommand
        } else {
            return nil
        }
        guard let agentSessionCommand = commandLaunchingAgentSession(
            from: parameterizedCommand,
            for: agent
        ) else {
            return nil
        }
        return LaunchCommand(command: agentSessionCommand, sourceCommandID: command.id)
    }

    func commandLaunchingAgentSession(
        from command: BmuxCommandDefinition,
        for agent: BmuxConfigAgentKind
    ) -> BmuxCommandDefinition? {
        guard let provider = agent.agentSessionProviderID,
              let workspace = command.workspace,
              let layout = workspace.layout else {
            return nil
        }
        let mutation = layoutByLaunchingAgentSession(in: layout, for: agent, provider: provider)
        guard mutation.didChange else { return command }
        var nextWorkspace = workspace
        nextWorkspace.layout = mutation.layout
        return BmuxCommandDefinition(
            name: command.name,
            description: command.description,
            keywords: command.keywords,
            restart: command.restart,
            workspace: nextWorkspace,
            command: command.command,
            confirm: command.confirm
        )
    }

    func command(
        byAppending selections: [RepoAgentLauncherParameterSelection],
        to command: BmuxCommandDefinition,
        for agent: BmuxConfigAgentKind
    ) -> BmuxCommandDefinition? {
        let arguments = selections.flatMap(\.renderedArguments)
        guard !arguments.isEmpty,
              let workspace = command.workspace,
              let layout = workspace.layout else {
            return command
        }
        let mutation = layoutByAppending(arguments: arguments, to: layout, for: agent)
        guard mutation.didChange else { return nil }
        var nextWorkspace = workspace
        nextWorkspace.layout = mutation.layout
        return BmuxCommandDefinition(
            name: command.name,
            description: command.description,
            keywords: command.keywords,
            restart: command.restart,
            workspace: nextWorkspace,
            command: command.command,
            confirm: command.confirm
        )
    }

    private func firstAgent(in node: BmuxLayoutNode) -> BmuxConfigAgentKind? {
        switch node {
        case .pane(let pane):
            for surface in pane.surfaces {
                switch surface.type {
                case .terminal:
                    guard let command = surface.command else { continue }
                    if commandMatchesAgent(command, agent: .codex) { return .codex }
                    if commandMatchesAgent(command, agent: .claudeCode) { return .claudeCode }
                case .agentSession:
                    if let agent = surface.provider?.repoAgentKind {
                        return agent
                    }
                case .browser, .project:
                    continue
                }
            }
            return nil
        case .split(let split):
            for child in split.children {
                if let agent = firstAgent(in: child) { return agent }
            }
            return nil
        }
    }

    private func layoutByLaunchingAgentSession(
        in node: BmuxLayoutNode,
        for agent: BmuxConfigAgentKind,
        provider: AgentSessionProviderID
    ) -> (layout: BmuxLayoutNode, didChange: Bool) {
        switch node {
        case .pane(let pane):
            var didChange = false
            let surfaces = pane.surfaces.map { surface in
                var next = surface
                switch surface.type {
                case .terminal:
                    guard let command = surface.command,
                          commandMatchesAgent(command, agent: agent) else {
                        return next
                    }
                    next.type = .agentSession
                    next.command = nil
                    next.env = nil
                    next.url = nil
                    next.provider = provider
                    next.renderer = .react
                    didChange = true
                case .agentSession:
                    if surface.provider == nil || surface.provider == provider {
                        next.provider = provider
                        next.renderer = surface.renderer ?? .react
                    }
                case .browser, .project:
                    break
                }
                return next
            }
            return (.pane(BmuxPaneDefinition(surfaces: surfaces)), didChange)
        case .split(let split):
            var didChange = false
            let children = split.children.map { child in
                let mutation = layoutByLaunchingAgentSession(in: child, for: agent, provider: provider)
                didChange = didChange || mutation.didChange
                return mutation.layout
            }
            return (.split(BmuxSplitDefinition(direction: split.direction, split: split.split, children: children)), didChange)
        }
    }

    private func layoutByAppending(
        arguments: [String],
        to node: BmuxLayoutNode,
        for agent: BmuxConfigAgentKind
    ) -> (layout: BmuxLayoutNode, didChange: Bool) {
        switch node {
        case .pane(let pane):
            var didChange = false
            let surfaces = pane.surfaces.map { surface in
                var next = surface
                if surface.type == .terminal,
                   let command = surface.command,
                   commandMatchesAgent(command, agent: agent) {
                    next.command = ([command] + arguments).joined(separator: " ")
                    didChange = true
                }
                return next
            }
            return (.pane(BmuxPaneDefinition(surfaces: surfaces)), didChange)
        case .split(let split):
            var didChange = false
            let children = split.children.map { child in
                let mutation = layoutByAppending(arguments: arguments, to: child, for: agent)
                didChange = didChange || mutation.didChange
                return mutation.layout
            }
            return (.split(BmuxSplitDefinition(direction: split.direction, split: split.split, children: children)), didChange)
        }
    }

    private func commandMatchesAgent(_ command: String, agent: BmuxConfigAgentKind) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(agent.commandName) else { return false }
        guard trimmed.count > agent.commandName.count else { return true }
        let index = trimmed.index(trimmed.startIndex, offsetBy: agent.commandName.count)
        return trimmed[index].isWhitespace
    }
}

extension BmuxConfigAgentKind {
    var agentSessionProviderID: AgentSessionProviderID? {
        switch self {
        case .codex:
            return .codex
        case .claudeCode:
            return .claude
        case .opencode:
            return .opencode
        case .custom:
            return nil
        }
    }
}

private extension AgentSessionProviderID {
    var repoAgentKind: BmuxConfigAgentKind {
        switch self {
        case .codex:
            return .codex
        case .claude:
            return .claudeCode
        case .opencode:
            return .opencode
        }
    }
}
