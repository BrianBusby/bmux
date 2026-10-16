import SwiftUI

/// Keeps transient pointer state local to one native control.
struct MatteButtonLabel: View {
    let configuration: ButtonStyleConfiguration
    let role: MatteControlRole
    let theme: MatteTheme
    let dimsWhenDisabled: Bool
    let isSelected: Bool
    let forcesHover: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @Environment(\.matteKeyboardFocusVisible) private var keyboardFocusVisible
    @Environment(\.matteButtonHitExpansion) private var hitExpansion
    @Environment(\.matteButtonIsFocused) private var matteButtonIsFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        let motion = theme.motion(reduceMotion: reduceMotion)
        let showsHover = isHovered || forcesHover
        configuration.label
            .foregroundStyle(Color(nsColor: theme.color(role == .link
                ? (showsHover && isEnabled ? .linkHover : .link) : .textSecondary)))
            .underline(role == .link && showsHover && isEnabled)
            .background {
                MatteControlDecoration(role: role, theme: theme, state: .init(
                    isSelected: isSelected, isHovered: showsHover, isPressed: configuration.isPressed,
                    isFocused: keyboardFocusVisible && (isFocused || matteButtonIsFocused), isEnabled: isEnabled))
            }
            .padding(hitExpansion)
            .contentShape(Rectangle())
            .compositingGroup()
            .opacity(isEnabled || !dimsWhenDisabled ? 1 : theme.layout.disabledOpacity)
            .onHover { isHovered = $0 }
            .animation(reduceMotion ? nil : .timingCurve(motion.curve.x1, motion.curve.y1,
                motion.curve.x2, motion.curve.y2, duration: motion.controlDuration), value: showsHover)
            .animation(reduceMotion ? nil : .timingCurve(motion.curve.x1, motion.curve.y1,
                motion.curve.x2, motion.curve.y2, duration: motion.controlDuration), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .timingCurve(motion.curve.x1, motion.curve.y1,
                motion.curve.x2, motion.curve.y2, duration: motion.controlDuration), value: isSelected)
    }
}
