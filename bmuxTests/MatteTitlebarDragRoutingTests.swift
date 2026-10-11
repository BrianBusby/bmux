import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite struct MatteTitlebarDragRoutingTests {
    @Test(arguments: TitlebarControlsStyle.allCases)
    func registeredControlsReceiveClicksAndEmptySpaceRemainsDraggable(style: TitlebarControlsStyle) throws {
        let controlFrame = NSRect(
            x: 72, y: 88,
            width: MinimalModeSidebarTitlebarControlsMetrics.hostWidth,
            height: MinimalModeSidebarTitlebarControlsMetrics.hostHeight
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: controlFrame.maxX + 40, height: 120),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        defer { window.orderOut(nil) }
        let contentView = try #require(window.contentView)
        let dragHandle = NSView(frame: contentView.bounds)
        contentView.addSubview(dragHandle)
        let controls = ControlRegion(frame: controlFrame)
        controls.config = style.config
        contentView.addSubview(controls)
        MinimalModeTitlebarControlHitRegionRegistry.register(controls)
        defer { MinimalModeTitlebarControlHitRegionRegistry.unregister(controls) }

        let ranges = TitlebarControlsHitRegions.buttonXRanges(config: controls.config)
        #expect(ranges.count == MinimalModeSidebarControlActionSlot.allCases.count)
        for range in ranges {
            let point = controls.convert(NSPoint(x: (range.lowerBound + range.upperBound) / 2, y: controls.bounds.midY), to: nil)
            #expect(isMinimalModeTitlebarControlHit(window: window, locationInWindow: point))
            #expect(!windowDragHandleShouldCaptureHit(
                dragHandle.convert(point, from: nil), in: dragHandle,
                eventType: .leftMouseDown, eventWindow: window
            ))
        }

        let gapCenters = zip(ranges, ranges.dropFirst()).compactMap { previous, next -> CGFloat? in
            guard previous.upperBound < next.lowerBound else { return nil }
            return controls.frame.minX + (previous.upperBound + next.lowerBound) / 2
        }
        #expect(!gapCenters.isEmpty)
        for x in gapCenters + [controls.frame.maxX + 20] {
            let point = contentView.convert(NSPoint(x: x, y: controls.frame.midY), to: nil)
            #expect(!isMinimalModeTitlebarControlHit(window: window, locationInWindow: point))
            #expect(windowDragHandleShouldCaptureHit(
                dragHandle.convert(point, from: nil), in: dragHandle,
                eventType: .leftMouseDown, eventWindow: window
            ))
        }
    }

    private final class ControlRegion: NSView, MinimalModeSidebarControlActionHitRegionProviding {
        // AppKit and the registry read this fixture synchronously on the main actor.
        nonisolated(unsafe) var config = TitlebarControlsStyle.classic.config

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        nonisolated func containsMinimalModeTitlebarControlHit(localPoint: NSPoint) -> Bool {
            minimalModeSidebarControlActionSlot(localPoint: localPoint) != nil
        }

        nonisolated func minimalModeSidebarControlActionSlot(localPoint: NSPoint) -> MinimalModeSidebarControlActionSlot? {
            TitlebarControlsHitRegions.sidebarActionSlot(at: localPoint, config: config)
        }
    }
}
