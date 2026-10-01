import Foundation
import Testing
@testable import Echo

/// Round 37.5: a tab's buttons travel to the window toolbar as data; the toolbar redraws only when
/// what it shows changes.
@MainActor
@Suite("Tab toolbar section")
struct TabToolbarSectionTests {
    @Test func itemsCompareByWhatTheyShowNotTheirAction() {
        var count = 0
        let first = TabToolbarItem(id: "trace", title: "Start Trace", symbol: "play.fill") { count += 1 }
        let second = TabToolbarItem(id: "trace", title: "Start Trace", symbol: "play.fill") { count += 2 }
        #expect(first == second)
        var running = second
        running.isRunning = true
        #expect(first != running)
        first.action()
        #expect(count == 1)
    }

    @Test func aMenuIsPartOfWhatAnItemShows() {
        let plain = TabToolbarItem(id: "export", title: "Export", symbol: "square.and.arrow.up")
        var withMenu = plain
        withMenu.menu = [TabToolbarItem(id: "png", title: "Export as PNG", symbol: "photo")]
        #expect(plain != withMenu)
    }

    @Test func refreshIsBusyAndDisabledWhileReloading() {
        let refresh = TabToolbarItem.refresh(isBusy: true) {}
        #expect(refresh.isBusy && refresh.isDisabled)
        #expect(refresh.symbol == "arrow.clockwise")
        #expect(!TabToolbarItem.refresh {}.isBusy)
    }

    @Test func aSectionWithNothingIsEmpty() {
        #expect(TabToolbarSection().isEmpty)
        #expect(TabToolbarSection(special: nil, groups: [[]]).isEmpty)
        #expect(!TabToolbarSection(special: .refresh {}).isEmpty)
        #expect(!TabToolbarSection(groups: [[.refresh {}]]).isEmpty)
    }

    @Test func theInnermostSectionWins() {
        let page = TabToolbarSection(special: TabToolbarItem(id: "newBackup", title: "New Backup", symbol: "plus"))
        let tool = TabToolbarSection(groups: [[.refresh {}]])
        var value: TabToolbarSection? = page
        TabToolbarSectionKey.reduce(value: &value) { tool }
        #expect(value == page)
        var none: TabToolbarSection?
        TabToolbarSectionKey.reduce(value: &none) { tool }
        #expect(none == tool)
    }
}
