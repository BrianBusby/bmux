import SwiftUI

/// Keeps unrelated defaults notifications outside the heavy workspace composition.
struct WorkspaceTitlebarInsetChangeObserver: View {
    let onChange: (MinimalModeTitlebarDebugSnapshot) -> Void

    @AppStorage(MinimalModeTitlebarDebugSettings.leftControlsLeadingInsetKey)
    private var leftControlsLeadingInset = MinimalModeTitlebarDebugSettings.defaultLeftControlsLeadingInset
    @AppStorage(MinimalModeTitlebarDebugSettings.leftControlsTopInsetKey)
    private var leftControlsTopInset = MinimalModeTitlebarDebugSettings.defaultLeftControlsTopInset
    @AppStorage(MinimalModeTitlebarDebugSettings.trafficLightTabBarInsetKey)
    private var trafficLightTabBarInset = MinimalModeTitlebarDebugSettings.defaultTrafficLightTabBarInset
    @AppStorage(MinimalModeTitlebarDebugSettings.trafficLightTitlebarLeadingInsetKey)
    private var trafficLightTitlebarLeadingInset = MinimalModeTitlebarDebugSettings.defaultTrafficLightTitlebarLeadingInset

    init(defaults: UserDefaults, onChange: @escaping (MinimalModeTitlebarDebugSnapshot) -> Void) {
        self.onChange = onChange
        _leftControlsLeadingInset = AppStorage(
            wrappedValue: MinimalModeTitlebarDebugSettings.defaultLeftControlsLeadingInset,
            MinimalModeTitlebarDebugSettings.leftControlsLeadingInsetKey, store: defaults
        )
        _leftControlsTopInset = AppStorage(
            wrappedValue: MinimalModeTitlebarDebugSettings.defaultLeftControlsTopInset,
            MinimalModeTitlebarDebugSettings.leftControlsTopInsetKey, store: defaults
        )
        _trafficLightTabBarInset = AppStorage(
            wrappedValue: MinimalModeTitlebarDebugSettings.defaultTrafficLightTabBarInset,
            MinimalModeTitlebarDebugSettings.trafficLightTabBarInsetKey, store: defaults
        )
        _trafficLightTitlebarLeadingInset = AppStorage(
            wrappedValue: MinimalModeTitlebarDebugSettings.defaultTrafficLightTitlebarLeadingInset,
            MinimalModeTitlebarDebugSettings.trafficLightTitlebarLeadingInsetKey, store: defaults
        )
    }

    private var snapshot: MinimalModeTitlebarDebugSnapshot {
        MinimalModeTitlebarDebugSnapshot(
            leftControlsLeadingInset: MinimalModeTitlebarDebugSettings.clamped(
                leftControlsLeadingInset, range: MinimalModeTitlebarDebugSettings.horizontalInsetRange
            ),
            leftControlsTopInset: MinimalModeTitlebarDebugSettings.clamped(
                leftControlsTopInset, range: MinimalModeTitlebarDebugSettings.topInsetRange
            ),
            trafficLightTabBarLeadingInset: MinimalModeTitlebarDebugSettings.clamped(
                trafficLightTabBarInset, range: MinimalModeTitlebarDebugSettings.horizontalInsetRange
            ),
            trafficLightTitlebarLeadingInset: MinimalModeTitlebarDebugSettings.clamped(
                trafficLightTitlebarLeadingInset, range: MinimalModeTitlebarDebugSettings.horizontalInsetRange
            )
        )
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .onAppear { onChange(snapshot) }
            .onChange(of: snapshot) { _, value in onChange(value) }
    }
}
