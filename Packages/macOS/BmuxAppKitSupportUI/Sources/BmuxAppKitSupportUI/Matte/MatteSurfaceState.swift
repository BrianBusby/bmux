/// Caller-owned interaction values used only to resolve matte decoration.
///
/// The surface never installs gestures, moves content, manages focus, or changes
/// selection. Card interactions affect only the card role. Focus applies to every
/// rounded surface; disabled surfaces suppress focus and hover decoration.
public struct MatteSurfaceState: Equatable, Sendable {
    /// Whether the card remains selected, including while disabled or pressed.
    public let isSelected: Bool
    /// Whether the pointer is over an enabled card.
    public let isHovered: Bool
    /// Whether an enabled card is pressed, suppressing its ambient shadow.
    public let isPressed: Bool
    /// Whether a rounded surface should draw the keyboard-focus outline.
    public let isFocused: Bool
    /// Whether interaction decoration is enabled; selection is retained when false.
    public let isEnabled: Bool

    /// Creates a stationary, enabled surface by default.
    /// - Parameters:
    ///   - isSelected: Current card selection supplied by its owner.
    ///   - isHovered: Current pointer presence supplied by its owner.
    ///   - isPressed: Current press state supplied by its owner.
    ///   - isFocused: Current keyboard focus supplied by its owner.
    ///   - isEnabled: Whether the surface can respond to interaction.
    public init(
        isSelected: Bool = false, isHovered: Bool = false, isPressed: Bool = false,
        isFocused: Bool = false, isEnabled: Bool = true
    ) {
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.isPressed = isPressed
        self.isFocused = isFocused
        self.isEnabled = isEnabled
    }
}
