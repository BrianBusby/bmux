import Foundation

struct RepoAgentLauncherCommandCustomizer {
    func agent(for command: BmuxCommandDefinition) -> BmuxConfigAgentKind? {
        guard let layout = command.workspace?.layout else { return nil }
        return firstAgent(in: layout)
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
                guard surface.type == .terminal,
                      let command = surface.command else {
                    continue
                }
                if commandMatchesAgent(command, agent: .codex) { return .codex }
                if commandMatchesAgent(command, agent: .claudeCode) { return .claudeCode }
            }
            return nil
        case .split(let split):
            for child in split.children {
                if let agent = firstAgent(in: child) { return agent }
            }
            return nil
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
