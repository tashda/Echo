import AppKit
import Testing
@testable import Echo

@MainActor
@Suite("Footer scroll bars (round 27)")
struct FooterScrollBarTests {
    @Test func barKeepsThePillsSpacingAboveThem() {
        let pills = LayoutTokens.Footer.pillInset
        #expect(pills == LayoutTokens.Footer.bottomLift + (LayoutTokens.Footer.height - LayoutTokens.Footer.chipHeight) / 2)
        #expect(LayoutTokens.Footer.scrollBarBottom == pills + LayoutTokens.Footer.chipHeight + pills)
    }

    @Test func appKitScrollerInsetAddsToTheFootersRoom() {
        let footer = LayoutTokens.Footer.height + LayoutTokens.Footer.bottomLift
        let inset = LayoutTokens.Footer.scrollerInset(overFooter: footer)
        // AppKit adds the scroller inset to the content inset; the thumb sits 3pt inside the frame.
        #expect(footer + inset + LayoutTokens.Footer.overlayThumbInset == LayoutTokens.Footer.scrollBarBottom)
    }

    @Test func noFooterLeavesTheBarsAlone() {
        #expect(LayoutTokens.Footer.scrollerInset(overFooter: 0) == 0)
        #expect(FooterScrollRoomMetrics.indicatorMargin(overFooter: 0) == 0)
    }

    @Test func swiftUIIndicatorMarginLandsWhereAppKitDoes() {
        let footer = LayoutTokens.Footer.height + LayoutTokens.Footer.bottomLift
        // SwiftUI places the bar at the indicators' margin less the content's margin.
        let swiftUIFrameBottom = FooterScrollRoomMetrics.indicatorMargin(overFooter: footer) - footer
        let appKitFrameBottom = footer + LayoutTokens.Footer.scrollerInset(overFooter: footer)
        #expect(swiftUIFrameBottom == appKitFrameBottom)
    }

    @Test func sidesFadeOnlyWhereTheViewCanStillScroll() {
        let atStart = ScrollSideFades.fadingSides(visible: NSRect(x: 0, y: 0, width: 600, height: 300), contentWidth: 2000)
        #expect(!atStart.leading && atStart.trailing)
        let middle = ScrollSideFades.fadingSides(visible: NSRect(x: 700, y: 0, width: 600, height: 300), contentWidth: 2000)
        #expect(middle.leading && middle.trailing)
        let atEnd = ScrollSideFades.fadingSides(visible: NSRect(x: 1400, y: 0, width: 600, height: 300), contentWidth: 2000)
        #expect(atEnd.leading && !atEnd.trailing)
        let narrow = ScrollSideFades.fadingSides(visible: NSRect(x: 0, y: 0, width: 600, height: 300), contentWidth: 500)
        #expect(!narrow.leading && !narrow.trailing)
    }
}
