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
        let open = (0..<(Host.keptTabCount + 2)).map { _ in UUID() }
        let newest = UUID()
        let ids = Host.recentTabIDs(open, activating: newest, openIDs: Set(open + [newest]))
        #expect(ids == [newest] + open.prefix(Host.keptTabCount - 1))
        #expect(ids.count == Host.keptTabCount)
    }

    @Test func onlyTheActiveKeptTabIsActive() {
        let activity = KeptAliveTabsActivity()
        activity.activeTabID = a
        #expect(KeptAliveTabsActivity.isActive(a, in: activity))
        #expect(!KeptAliveTabsActivity.isActive(b, in: activity))
    }

    @Test func aTabOutsideKeptTabsIsAlwaysActive() {
        #expect(KeptAliveTabsActivity.isActive(nil, in: KeptAliveTabsActivity()))
        #expect(KeptAliveTabsActivity.isActive(a, in: nil))
    }

    @Test func closedTabsDropOut() {
        let ids = Host.recentTabIDs([a, b, c], activating: c, openIDs: [a, c])
        #expect(ids == [c, a])
    }
}
