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

@MainActor
@Suite("Scroll bar blur (round 27, U5)")
struct ScrollBarBlurTests {
    @Test func aStepFadesOutAtItsShareOfTheReach() {
        let stops = BackdropEdgeBlurLayerView.locations(reach: 60, of: 120, share: 1)
        #expect(stops.first == 0)
        #expect(stops.last == 0.5)
        #expect(stops == stops.sorted())
        #expect(stops[1] == 0.5 - 0.5 * LayoutTokens.EdgeBlur.band)
    }

    @Test func weakerStepsReachLess() {
        let full = BackdropEdgeBlurLayerView.locations(reach: 100, of: 100, share: 1)
        let half = BackdropEdgeBlurLayerView.locations(reach: 100, of: 100, share: 0.5)
        #expect(half.last == 0.5)
        #expect(full.last == 1)
    }

    @Test func nothingReachedIsClear() {
        let stops = BackdropEdgeBlurLayerView.locations(reach: 0, of: 100, share: 1)
        #expect(stops.allSatisfy { $0 == 0 })
        #expect(BackdropEdgeBlurLayerView.locations(reach: 50, of: 0, share: 1).allSatisfy { $0 == 0 })
    }

    /// The steps stack, so the blur's strength at a height is the root of the summed squared
    /// radii, each weighted by its mask there. It must grow evenly from sharp to strongest: no
    /// jump within a row reads as a line (owner, after round 27).
    @Test func theBlurGrowsEvenlyFromSharpToTheEdge() {
        let reach: CGFloat = LayoutTokens.Footer.height + LayoutTokens.Footer.bottomLift + LayoutTokens.EdgeBlur.fade
        let radii = LayoutTokens.EdgeBlur.radii
        let alphas = BackdropEdgeBlurLayerView.fadeAlphas
        func mask(_ stops: [CGFloat], at share: CGFloat) -> CGFloat {
            guard share > stops[0] else { return alphas[0] }
            for index in 1..<stops.count where share <= stops[index] {
                let span = stops[index] - stops[index - 1]
                let t = span > 0 ? (share - stops[index - 1]) / span : 1
                return alphas[index - 1] + (alphas[index] - alphas[index - 1]) * t
            }
            return 0
        }
        let steps = radii.indices.map { index in
            BackdropEdgeBlurLayerView.locations(reach: reach, of: reach, share: 1 - CGFloat(index) / CGFloat(radii.count))
        }
        let strength = stride(from: CGFloat(0), through: reach, by: 1).map { height in
            zip(radii, steps).reduce(CGFloat(0)) { $0 + $1.0 * $1.0 * mask($1.1, at: height / reach) }.squareRoot()
        }
        #expect(strength.first ?? 0 > 10)
        #expect(strength.last == 0)
        let steepest = zip(strength, strength.dropFirst()).map { abs($0 - $1) }.max() ?? 0
        #expect(steepest < 0.6, "the blur changes by \(steepest)pt of radius in one point of height")
    }

    @Test func theFadeIsAnSCurve() {
        let alphas = BackdropEdgeBlurLayerView.fadeAlphas
        #expect(alphas.first == 1 && alphas.last == 0)
        #expect(alphas == alphas.sorted(by: >))
        // Symmetric around the middle, as smoothstep is.
        #expect(abs(alphas[2] + alphas[4] - 1) < 0.0001)
    }

    @Test func raisedBlurPassesTheWidestThumb() {
        let barThumb = LayoutTokens.Footer.scrollBarBottom
        let raised = barThumb + LayoutTokens.Footer.overlayThumbMaxHeight + LayoutTokens.EdgeBlur.fade
        #expect(raised > LayoutTokens.Footer.height + LayoutTokens.Footer.bottomLift + LayoutTokens.EdgeBlur.fade)
    }
}

/// Round 44: the system's material under the footer, faded in exponentially (BT4, CV6, BH3, TT1).
@Suite("Footer material (round 44)")
struct FooterMaterialBlurTests {
    @Test func itFadesFromClearToFull() {
        #expect(FooterMaterialBlur.amount(at: 0) == 0)
        #expect(abs(FooterMaterialBlur.amount(at: 1) - 1) < 0.0001)
        let amounts = FooterMaterialBlur.stops().map(\.opacity)
        #expect(amounts == amounts.sorted())
    }

    /// Most of its height is spent where it is still faint, so no row meets it at once.
    @Test func itStartsSlowly() {
        #expect(FooterMaterialBlur.amount(at: 0.5) < 0.15)
        let steepest = zip(FooterMaterialBlur.stops(), FooterMaterialBlur.stops().dropFirst())
            .map { $1.opacity - $0.opacity }.max() ?? 0
        #expect(steepest < 0.2)
    }

    /// It reaches past the horizontal scroll bar, so the blur behind the bar needs nothing more.
    @Test func itReachesPastTheScrollBar() {
        let reach = LayoutTokens.Footer.height + LayoutTokens.Footer.bottomLift + LayoutTokens.EdgeBlur.materialReach
        #expect(reach > LayoutTokens.Footer.scrollBarBottom + LayoutTokens.Footer.overlayThumbMaxHeight)
    }
}
