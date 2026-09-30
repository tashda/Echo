import Foundation
import Testing
import SwiftUI
@testable import Echo

@MainActor
@Suite("Card split")
struct CardSplitViewTests {
    @Test(arguments: [(0.5, 0.5), (0.05, 0.2), (0.95, 0.8), (0.2, 0.2)])
    func fractionStaysWithinTheMinimums(value: Double, expected: Double) {
        #expect(CardSplitView<EmptyView, EmptyView>.clamped(CGFloat(value), min: 0.2) == CGFloat(expected))
    }

    /// A sidebar pane such as the Query Builder's tables stops at its own maximum.
    @Test(arguments: [(0.5, 0.35), (0.05, 0.14), (0.2, 0.2)])
    func fractionStaysWithinAnUpperBound(value: Double, expected: Double) {
        #expect(CardSplitView<EmptyView, EmptyView>.clamped(CGFloat(value), min: 0.14, max: 0.35) == CGFloat(expected))
    }

    /// Any card below a container turns its adaptive card off (TT1).
    @Test(arguments: [([false, false], false), ([false, true], true), ([true, false], true), ([], false)])
    func containsCardReportsAnyInnerCard(children: [Bool], expected: Bool) {
        var value = ContainsWorkspaceCardKey.defaultValue
        for child in children { ContainsWorkspaceCardKey.reduce(value: &value) { child } }
        #expect(value == expected)
    }

    @Test func chromelessCardLeavesRoomForInnerShadows() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 50)
        let open = WorkspaceCardClipShape(cornerRadius: 12, clips: false).path(in: rect).boundingRect
        let clipped = WorkspaceCardClipShape(cornerRadius: 12, clips: true).path(in: rect).boundingRect
        #expect(open.contains(rect.insetBy(dx: -ShadowTokens.workspaceCard.radius, dy: -ShadowTokens.workspaceCard.radius)))
        #expect(clipped == rect)
    }
}
