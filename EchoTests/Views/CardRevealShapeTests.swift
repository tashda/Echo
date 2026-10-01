import SwiftUI
import Testing
@testable import Echo

@Suite("Card reveal shape")
struct CardRevealShapeTests {
    private let rect = CGRect(x: 0, y: 0, width: 200, height: 300)

    @Test func topAnchorHangsFromTheTop() {
        let bounds = CardRevealShape(visibleHeight: 120, cornerRadius: 12, anchor: .top).path(in: rect).boundingRect
        #expect(bounds.minY == 0)
        #expect(bounds.height == 120)
    }

    @Test func bottomAnchorRisesFromTheBottom() {
        let bounds = CardRevealShape(visibleHeight: 50, cornerRadius: 12, anchor: .bottom).path(in: rect).boundingRect
        #expect(bounds.maxY == 300)
        #expect(bounds.height == 50)
    }

    @Test func neverExceedsTheLaidOutSize() {
        let bounds = CardRevealShape(visibleHeight: 900, cornerRadius: 12, anchor: .top).path(in: rect).boundingRect
        #expect(bounds.height == 300)
        #expect(CardRevealShape(visibleHeight: 0, cornerRadius: 12, anchor: .bottom).path(in: rect).isEmpty)
    }
}
