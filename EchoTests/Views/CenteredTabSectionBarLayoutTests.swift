import CoreGraphics
import Testing
@testable import Echo

@Suite("Centered tab section bar")
struct CenteredTabSectionBarLayoutTests {
    private let sizes = CenteredTabSectionBarLayout.Sizes(center: CGSize(width: 300, height: 28), controls: CGSize(width: 100, height: 24))

    @Test func centringReservesTheControlsOnBothSides() {
        #expect(CenteredTabSectionBarLayout.centredWidth(sizes, spacing: 12) == CGFloat(524))
    }

    @Test func stacksOnlyWhenTheCentredRowDoesNotFit() {
        #expect(!CenteredTabSectionBarLayout.isStacked(sizes, width: 524, spacing: 12))
        #expect(CenteredTabSectionBarLayout.isStacked(sizes, width: 523, spacing: 12))
        #expect(!CenteredTabSectionBarLayout.isStacked(sizes, width: nil, spacing: 12))
    }

    @Test func withoutControlsItNeverStacks() {
        let alone = CenteredTabSectionBarLayout.Sizes(center: CGSize(width: 300, height: 28), controls: .zero)
        #expect(!CenteredTabSectionBarLayout.isStacked(alone, width: 100, spacing: 12))
    }
}
