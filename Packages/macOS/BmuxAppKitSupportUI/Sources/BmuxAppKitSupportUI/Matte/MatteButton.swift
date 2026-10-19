public import SwiftUI

/// A native button with explicit keyboard focus and one shared activation action.
///
/// Apply ``MatteButtonStyle`` or a caller-owned button style. Pointer activation,
/// Space, and Return all invoke the same closure and honor the enabled environment.
public struct MatteButton<Label: View>: View {
    private let hitExpansion: CGFloat
    private let action: () -> Void
    private let onFocusChange: ((Bool) -> Void)?
    private let label: Label
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool

    /// Creates a button without introducing a second owner of domain actions.
    /// - Parameters:
    ///   - hitExpansion: Invisible padding supplied to MatteButtonStyle, compensated outside the button.
    ///   - action: The existing action shared by pointer and keyboard activation.
    ///   - onFocusChange: Optional local focus feedback for a surrounding card.
    ///   - label: The original accessible label, including its hit-target size.
    public init(hitExpansion: CGFloat = 0, action: @escaping () -> Void, onFocusChange: ((Bool) -> Void)? = nil,
                @ViewBuilder label: () -> Label) {
        self.hitExpansion = hitExpansion
        self.action = action
        self.onFocusChange = onFocusChange
        self.label = label()
    }

    /// The native button and its local focus and keyboard handling.
    public var body: some View {
        Button(action: activate) { label }
            .environment(\.matteButtonIsFocused, isFocused)
            .environment(\.matteButtonHitExpansion, hitExpansion)
            .focusable(isEnabled)
            .focusEffectDisabled()
            .focused($isFocused)
            .onKeyPress(keys: [.space, .return], phases: .down) { key in
                guard Self.acceptsKeyboardActivation(isEnabled: isEnabled, modifiers: key.modifiers) else { return .ignored }
                activate()
                return .handled
            }
            .onChange(of: isFocused && isEnabled) { _, value in onFocusChange?(value) }
            .onChange(of: isEnabled) { _, enabled in if !enabled { isFocused = false } }
            .onDisappear { onFocusChange?(false) }
            .padding(-hitExpansion)
    }

    static func acceptsKeyboardActivation(isEnabled: Bool, modifiers: EventModifiers) -> Bool {
        isEnabled && modifiers.intersection([.command, .control, .option, .shift]).isEmpty
    }

    private func activate() {
        guard isEnabled else { return }
        action()
    }
}
