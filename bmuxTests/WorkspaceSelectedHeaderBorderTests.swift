import AppKit
import BmuxSidebar
import SwiftUI
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite struct WorkspaceSelectedHeaderBorderTests {
    @Test func missingResourceURLsProduceNoHeaderItems() {
        let resources = SidebarWorkspaceSnapshotBuilder.resourceLinkPresentation(
            pullRequestRows: [],
            projectRows: [],
            ticketRows: [
                SidebarWorkspaceSnapshotBuilder.TicketDisplay(
                    id: "STE-1964",
                    title: nil,
                    url: nil,
                    ownerName: "Brian Busby",
                    ownerURL: nil
                )
            ]
        )

        #expect(!resources.hasHeaderItems)
        #expect(resources.headerItems.isEmpty)
    }

    @Test func resourcePresentationHeaderItemsAreDeterministic() throws {
        let resources = SidebarWorkspaceSnapshotBuilder.resourceLinkPresentation(
            pullRequestRows: [Self.pullRequest(number: 57, title: "Unify workspace header", ownerLogin: "octocat")],
            projectRows: [
                SidebarWorkspaceSnapshotBuilder.ProjectDisplay(
                    id: "context-efficiency",
                    title: "Context Efficiency",
                    url: URL(string: "https://linear.app/companycam/project/context-efficiency")!
                )
            ],
            ticketRows: [
                SidebarWorkspaceSnapshotBuilder.TicketDisplay(
                    id: "STE-1964",
                    title: "Canonical domain mutation paths",
                    url: URL(string: "https://linear.app/companycam/issue/STE-1964")!,
                    ownerName: "Brian Busby",
                    ownerURL: URL(string: "https://linear.app/companycam/user/brian")!
                )
            ]
        )

        #expect(resources.headerItems.map(\.kind) == [.ticket, .pullRequest, .project, .owner, .owner])
        #expect(resources.headerItems.map(\.text) == [
            "STE-1964: Canonical domain mutation paths",
            "#57",
            "Context Efficiency",
            "octocat",
            "Brian Busby",
        ])
    }

    @Test func selectedHeaderPlacementSuppressesOnlySelectedSidebarResources() {
        let resources = Self.ticketResourcePresentation()

        let selectedHeader = SidebarWorkspaceSnapshotBuilder.selectedWorkspaceHeaderResources(
            resources,
            isSelected: true
        )
        let unselectedHeader = SidebarWorkspaceSnapshotBuilder.selectedWorkspaceHeaderResources(
            resources,
            isSelected: false
        )

        #expect(selectedHeader == resources)
        #expect(unselectedHeader == nil)
        #expect(SidebarWorkspaceSnapshotBuilder.sidebarResourceRows(resources: resources, selectedWorkspaceHeaderResources: selectedHeader).ticketRows.isEmpty)
        #expect(SidebarWorkspaceSnapshotBuilder.sidebarResourceRows(resources: resources, selectedWorkspaceHeaderResources: unselectedHeader).ticketRows.map(\.id) == ["STE-1964"])
    }

    @Test func selectedSidebarRetainsRowsNotRepresentedInHeader() {
        let ticketURL = URL(string: "https://linear.app/companycam/issue/STE-1964")!
        let resources = SidebarWorkspaceSnapshotBuilder.resourceLinkPresentation(
            pullRequestRows: [Self.pullRequest(number: 57, title: "Unify workspace header", ownerLogin: "octocat")],
            projectRows: [],
            ticketRows: [
                SidebarWorkspaceSnapshotBuilder.TicketDisplay(
                    id: "STE-1964",
                    title: nil,
                    url: nil,
                    ownerName: nil,
                    ownerURL: nil
                ),
                SidebarWorkspaceSnapshotBuilder.TicketDisplay(
                    id: "STE-2000",
                    title: "Linked ticket with unlinked owner",
                    url: ticketURL,
                    ownerName: "Brian Busby",
                    ownerURL: nil
                ),
            ]
        )
        let selectedHeader = SidebarWorkspaceSnapshotBuilder.selectedWorkspaceHeaderResources(resources, isSelected: true)
        let rows = SidebarWorkspaceSnapshotBuilder.sidebarResourceRows(
            resources: resources,
            selectedWorkspaceHeaderResources: selectedHeader
        )

        #expect(rows.pullRequestRows.isEmpty)
        #expect(rows.ticketRows.map(\.id) == ["STE-1964", "STE-2000"])
        #expect(rows.hiddenTicketURLs == Set([ticketURL]))
        #expect(rows.pullRequestOwnerRows.isEmpty)
    }

    @Test func switchingSelectionTransfersHeaderPlacement() {
        let resources = Self.ticketResourcePresentation()

        #expect(SidebarWorkspaceSnapshotBuilder.selectedWorkspaceHeaderResources(resources, isSelected: true) != nil)
        #expect(SidebarWorkspaceSnapshotBuilder.selectedWorkspaceHeaderResources(resources, isSelected: false) == nil)
        #expect(SidebarWorkspaceSnapshotBuilder.selectedWorkspaceHeaderResources(resources, isSelected: false) == nil)
        #expect(SidebarWorkspaceSnapshotBuilder.selectedWorkspaceHeaderResources(resources, isSelected: true) != nil)
    }

    @Test func selectedBorderUsesTwoPixelRoundedGeometry() {
        let geometry = SelectedWorkspaceConnectedBorderGeometry.resolve(
            containerSize: CGSize(width: 900, height: 600),
            sidebarWidth: 240,
            rightSidebarWidth: 120,
            selectedRowFrame: CGRect(x: 8, y: 100, width: 224, height: 64)
        )

        #expect(geometry.lineWidth == 2)
        #expect(geometry.cornerRadius == SidebarWorkspaceSelectionBorderMetrics.connectedCornerRadius)
    }

    @Test func selectedBorderOmitsTabRightSideAndWorkspaceSharedSegment() {
        let geometry = SelectedWorkspaceConnectedBorderGeometry.resolve(
            containerSize: CGSize(width: 900, height: 600),
            sidebarWidth: 240,
            rightSidebarWidth: 120,
            selectedRowFrame: CGRect(x: 8, y: 100, width: 224, height: 64)
        )

        #expect(!geometry.containsVerticalSegment(x: 240, fromY: 100, toY: 164))
        #expect(geometry.containsVerticalSegment(x: 240, fromY: 0, toY: 100))
        #expect(geometry.containsVerticalSegment(x: 240, fromY: 164, toY: 600))
        #expect(geometry.containsHorizontalSegment(y: 100, fromX: 8, toX: 240))
        #expect(geometry.containsVerticalSegment(x: 8, fromY: 100, toY: 164))
        #expect(geometry.containsHorizontalSegment(y: 164, fromX: 8, toX: 240))
    }

    @Test func selectedBorderTopStartsBelowTitlebarChrome() {
        let geometry = SelectedWorkspaceConnectedBorderGeometry.resolve(
            containerSize: CGSize(width: 900, height: 600),
            sidebarWidth: 240,
            rightSidebarWidth: 120,
            selectedRowFrame: CGRect(x: 8, y: 100, width: 224, height: 64),
            workspaceTopY: WindowChromeMetrics.appTitlebarHeight
        )

        #expect(geometry.workspaceTopY == WindowChromeMetrics.appTitlebarHeight)
        #expect(geometry.containsHorizontalSegment(
            y: WindowChromeMetrics.appTitlebarHeight,
            fromX: 240,
            toX: 780
        ))
        #expect(!geometry.containsHorizontalSegment(y: 0, fromX: 240, toX: 780))
        #expect(geometry.containsVerticalSegment(
            x: 240,
            fromY: WindowChromeMetrics.appTitlebarHeight,
            toY: 100
        ))
    }

    @Test func selectedBorderGeometryTracksSidebarResizeAndSelectedRowMovement() {
        let geometry = SelectedWorkspaceConnectedBorderGeometry.resolve(
            containerSize: CGSize(width: 1000, height: 700),
            sidebarWidth: 300,
            rightSidebarWidth: 180,
            selectedRowFrame: CGRect(x: 12, y: 220, width: 270, height: 70)
        )

        #expect(geometry.containsHorizontalSegment(y: 0, fromX: 300, toX: 820))
        #expect(geometry.containsVerticalSegment(x: 300, fromY: 0, toY: 220))
        #expect(geometry.containsVerticalSegment(x: 300, fromY: 290, toY: 700))
        #expect(!geometry.containsVerticalSegment(x: 300, fromY: 220, toY: 290))
    }

    @Test func selectedTabFillExtendsIntoConnectedBorderJunction() {
        #expect(
            SidebarWorkspaceSelectionBorderMetrics.selectedTabConnectionFillExtensionWidth ==
                SidebarWorkspaceListMetrics.rowOuterHorizontalPadding +
                SidebarWorkspaceSelectionBorderMetrics.connectedCornerRadius
        )
    }

    @Test func selectedSolidFillRowsRetainAssignedWorkspaceColor() throws {
        let assignedColorHexes = [
            try #require(WorkspaceTabColorSettings.defaultPalette.first?.hex),
            "#12ABCD",
        ]

        for colorScheme in [ColorScheme.light, .dark] {
            for hex in assignedColorHexes {
                let style = sidebarWorkspaceRowBackgroundStyle(
                    activeTabIndicatorStyle: .solidFill,
                    isActive: true,
                    isMultiSelected: false,
                    customColorHex: hex,
                    colorScheme: colorScheme,
                    sidebarSelectionColorHex: "#FF00FF"
                )
                let expectedColor = try #require(WorkspaceTabColorSettings.displayNSColor(
                    hex: hex,
                    colorScheme: colorScheme,
                    forceBright: false
                ))

                #expect(style.color?.hexString() == expectedColor.hexString())
                #expect(style.opacity == 0.46)
            }
        }
    }

    private static func pullRequest(
        number: Int,
        title: String? = nil,
        ownerLogin: String? = nil
    ) -> SidebarWorkspaceSnapshotBuilder.PullRequestDisplay {
        SidebarWorkspaceSnapshotBuilder.PullRequestDisplay(
            id: "pr#\(number)|https://github.com/manaflow-ai/bmux/pull/\(number)",
            number: number,
            title: title,
            label: "PR",
            url: URL(string: "https://github.com/manaflow-ai/bmux/pull/\(number)")!,
            status: .open,
            ownerLogin: ownerLogin,
            ownerURL: ownerLogin.flatMap { URL(string: "https://github.com/\($0)") },
            branch: nil,
            isStale: false,
            isFromProvenance: false
        )
    }

    private static func ticketResourcePresentation() -> SidebarWorkspaceSnapshotBuilder.ResourceLinkPresentation {
        SidebarWorkspaceSnapshotBuilder.resourceLinkPresentation(
            pullRequestRows: [],
            projectRows: [],
            ticketRows: [
                SidebarWorkspaceSnapshotBuilder.TicketDisplay(
                    id: "STE-1964",
                    title: nil,
                    url: URL(string: "https://linear.app/companycam/issue/STE-1964")!,
                    ownerName: nil,
                    ownerURL: nil
                )
            ]
        )
    }
}

private extension SelectedWorkspaceConnectedBorderGeometry {
    func containsHorizontalSegment(y: CGFloat, fromX: CGFloat, toX: CGFloat) -> Bool {
        segments.contains {
            $0.start.y == y && $0.end.y == y &&
                min($0.start.x, $0.end.x) == min(fromX, toX) &&
                max($0.start.x, $0.end.x) == max(fromX, toX)
        }
    }

    func containsVerticalSegment(x: CGFloat, fromY: CGFloat, toY: CGFloat) -> Bool {
        segments.contains {
            $0.start.x == x && $0.end.x == x &&
                min($0.start.y, $0.end.y) == min(fromY, toY) &&
                max($0.start.y, $0.end.y) == max(fromY, toY)
        }
    }
}
