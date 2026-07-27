import AppKit
import Foundation

extension AppDelegate {
    func promptForRepoAgentLauncherParametersIfRequested(
        actionTitle: String,
        agent: BmuxConfigAgentKind,
        presentingWindow: NSWindow?
    ) -> [RepoAgentLauncherParameterSelection]? {
        let definitions = RepoAgentLauncherParameterCatalog().definitions(for: agent)
        guard !definitions.isEmpty else { return [] }

        let alert = NSAlert()
        alert.messageText = String(
            localized: "dialog.repoAgentLauncher.launchParams.title",
            defaultValue: "Launch with Custom Params?"
        )
        let format = String(
            localized: "dialog.repoAgentLauncher.launchParams.message",
            defaultValue: "Launch %@ normally or choose command-line parameters for this run."
        )
        alert.informativeText = String(format: format, actionTitle)
        alert.addButton(withTitle: String(localized: "dialog.repoAgentLauncher.launchParams.normal", defaultValue: "Launch Normally"))
        alert.addButton(withTitle: String(localized: "dialog.repoAgentLauncher.launchParams.customize", defaultValue: "Customize..."))
        alert.addButton(withTitle: String(localized: "dialog.repoAgentLauncher.launchParams.cancel", defaultValue: "Cancel"))

        switch runBmuxModalAlert(alert, presentingWindow: presentingWindow) {
        case .alertFirstButtonReturn:
            return []
        case .alertSecondButtonReturn:
            return promptForRepoAgentLauncherParameters(
                definitions: definitions,
                actionTitle: actionTitle,
                presentingWindow: presentingWindow
            )
        default:
            return nil
        }
    }

    func executeRepoAgentLauncherAction(
        _ action: BmuxResolvedConfigAction,
        parameters: [RepoAgentLauncherParameterSelection],
        context: MainWindowContext,
        preferredWindow: NSWindow?
    ) -> Bool {
        guard let bmuxConfigStore = context.bmuxConfigStore,
              let launch = RepoAgentLauncherCommandCustomizer().launchCommand(
                for: action,
                commands: bmuxConfigStore.loadedCommands,
                parameters: parameters
              ) else {
            return false
        }

        let rawCwd = context.tabManager.selectedWorkspace?.currentDirectory
        let baseCwd = (rawCwd?.isEmpty == false) ? rawCwd!
            : FileManager.default.homeDirectoryForCurrentUser.path
        return BmuxConfigExecutor.execute(
            command: launch.command,
            tabManager: context.tabManager,
            baseCwd: baseCwd,
            configSourcePath: bmuxConfigStore.commandSourcePaths[launch.sourceCommandID] ?? action.actionSourcePath,
            globalConfigPath: bmuxConfigStore.globalConfigPath,
            displayTitle: action.title,
            actionID: action.id,
            icon: action.icon,
            iconSourcePath: action.iconSourcePath,
            presentingWindow: preferredWindow
        )
    }

    private func promptForRepoAgentLauncherParameters(
        definitions: [RepoAgentLauncherParameterDefinition],
        actionTitle: String,
        presentingWindow: NSWindow?
    ) -> [RepoAgentLauncherParameterSelection]? {
        while true {
            let rows = definitions.map(RepoAgentLauncherParameterRowController.init(definition:))
            let alert = NSAlert()
            alert.messageText = String(
                localized: "dialog.repoAgentLauncher.params.title",
                defaultValue: "Choose Command-Line Params"
            )
            let format = String(
                localized: "dialog.repoAgentLauncher.params.message",
                defaultValue: "Choose parameters to add when launching %@."
            )
            alert.informativeText = String(format: format, actionTitle)
            alert.addButton(withTitle: String(localized: "dialog.repoAgentLauncher.params.launch", defaultValue: "Launch"))
            alert.addButton(withTitle: String(localized: "dialog.repoAgentLauncher.params.back", defaultValue: "Back"))
            alert.addButton(withTitle: String(localized: "dialog.repoAgentLauncher.params.cancel", defaultValue: "Cancel"))
            alert.accessoryView = repoAgentLauncherParameterAccessoryView(rows: rows)

            switch runBmuxModalAlert(alert, presentingWindow: presentingWindow) {
            case .alertFirstButtonReturn:
                var selections: [RepoAgentLauncherParameterSelection] = []
                var missingFlag: String?
                for row in rows where row.checkbox.state == .on {
                    let value = row.selectedValue ?? ""
                    if row.requiresNonEmptyValue && value.isEmpty {
                        missingFlag = row.definition.flag
                        break
                    }
                    selections.append(RepoAgentLauncherParameterSelection(
                        definition: row.definition,
                        value: value.isEmpty ? nil : value
                    ))
                }
                if let missingFlag {
                    showRepoAgentLauncherMissingParameterValue(
                        missingFlag,
                        presentingWindow: presentingWindow
                    )
                    continue
                }
                return selections
            case .alertSecondButtonReturn:
                return promptForRepoAgentLauncherParametersIfRequested(
                    actionTitle: actionTitle,
                    agent: definitions[0].agent,
                    presentingWindow: presentingWindow
                )
            default:
                return nil
            }
        }
    }

    private func repoAgentLauncherParameterAccessoryView(
        rows: [RepoAgentLauncherParameterRowController]
    ) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        for row in rows {
            let comment = NSTextField(labelWithString: row.definition.comment)
            comment.font = NSFont.systemFont(ofSize: 11)
            comment.textColor = .secondaryLabelColor
            comment.lineBreakMode = .byTruncatingTail

            let valueView: NSView = row.textField
                ?? row.popupButton
                ?? NSView(frame: NSRect(x: 0, y: 0, width: 190, height: 24))
            let rowStack = NSStackView(views: [row.checkbox, valueView, comment])
            rowStack.orientation = .horizontal
            rowStack.alignment = .centerY
            rowStack.spacing = 8
            row.checkbox.widthAnchor.constraint(equalToConstant: 270).isActive = true
            valueView.widthAnchor.constraint(equalToConstant: 190).isActive = true
            comment.widthAnchor.constraint(equalToConstant: 150).isActive = true
            stack.addArrangedSubview(rowStack)
        }

        let rowHeight = 34
        let contentHeight = max(120, rows.count * rowHeight)
        let scrollHeight = min(360, contentHeight)
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 640, height: scrollHeight))
        scrollView.hasVerticalScroller = rows.count > 8
        scrollView.drawsBackground = false

        let documentView = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: contentHeight))
        stack.frame = NSRect(x: 0, y: 0, width: 640, height: contentHeight)
        documentView.addSubview(stack)
        scrollView.documentView = documentView
        return scrollView
    }

    private func showRepoAgentLauncherMissingParameterValue(
        _ flag: String,
        presentingWindow: NSWindow?
    ) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(
            localized: "dialog.repoAgentLauncher.params.missingValue.title",
            defaultValue: "Parameter Needs a Value"
        )
        let format = String(
            localized: "dialog.repoAgentLauncher.params.missingValue.message",
            defaultValue: "Enter a value for %@ or deselect it."
        )
        alert.informativeText = String(format: format, flag)
        alert.addButton(withTitle: String(localized: "dialog.repoAgentLauncher.params.missingValue.ok", defaultValue: "OK"))
        _ = runBmuxModalAlert(alert, presentingWindow: presentingWindow)
    }
}
