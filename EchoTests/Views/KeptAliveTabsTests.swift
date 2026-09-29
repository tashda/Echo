import Foundation
import SwiftUI
import Testing
@testable import Echo

@MainActor
@Suite("Kept-alive tabs")
struct KeptAliveTabsTests {
    private typealias Host = KeptAliveTabsView<EmptyView>
    private let a = UUID(), b = UUID(), c = UUID(), d = UUID()

    @Test func activatedTabGoesFirst() {
        let ids = Host.recentTabIDs([a, b], activating: b, openIDs: [a, b])
        #expect(ids == [b, a])
    }

    @Test func keepsOnlyTheMostRecentTabs() {
        let ids = Host.recentTabIDs([a, b, c], activating: d, openIDs: [a, b, c, d])
        #expect(ids == [d, a, b])
        #expect(ids.count == Host.keptTabCount)
    }

    @Test func closedTabsDropOut() {
        let ids = Host.recentTabIDs([a, b, c], activating: c, openIDs: [a, c])
        #expect(ids == [c, a])
    }
}
