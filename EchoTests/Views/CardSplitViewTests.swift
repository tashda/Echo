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
}
