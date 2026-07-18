import AppKit

@MainActor
final class RepoAgentLauncherParameterRowController: NSObject {
    let definition: RepoAgentLauncherParameterDefinition
    let checkbox: NSButton
    let textField: NSTextField?
    let popupButton: NSPopUpButton?

    init(definition: RepoAgentLauncherParameterDefinition) {
        self.definition = definition
        checkbox = NSButton(checkboxWithTitle: definition.flag, target: nil, action: nil)

        switch definition.valueKind {
        case .none:
            textField = nil
            popupButton = nil
        case .text(let placeholder), .optionalText(let placeholder):
            let field = NSTextField(string: "")
            field.placeholderString = placeholder
            field.frame = NSRect(x: 0, y: 0, width: 190, height: 24)
            textField = field
            popupButton = nil
        case .choice(let options):
            let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 190, height: 26), pullsDown: false)
            for option in options {
                popup.addItem(withTitle: option.label)
                popup.lastItem?.representedObject = option.value
            }
            textField = nil
            popupButton = popup
        }

        super.init()
        checkbox.target = self
        checkbox.action = #selector(updateEnabledState)
        updateEnabledState()
    }

    @objc func updateEnabledState() {
        let isSelected = checkbox.state == .on
        textField?.isEnabled = isSelected
        popupButton?.isEnabled = isSelected
    }

    var selectedValue: String? {
        switch definition.valueKind {
        case .none:
            return nil
        case .text, .optionalText:
            return textField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        case .choice:
            return popupButton?.selectedItem?.representedObject as? String
        }
    }

    var requiresNonEmptyValue: Bool {
        if case .text = definition.valueKind { return true }
        return false
    }
}
