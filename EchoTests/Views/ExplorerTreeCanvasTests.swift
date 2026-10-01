import CoreGraphics
import Testing
@testable import Echo

/// The tree places its rows itself (ExplorerTreeCanvas, 2026-10-01): the stretch it builds rows
/// for must always cover the view, change only in steps, and the room held below the last card
/// must follow the rows' height.
@MainActor
@Suite("Explorer tree canvas")
struct ExplorerTreeCanvasTests {
    @Test func theWindowAlwaysCoversTheViewWithAMargin() {
        let viewport: CGFloat = 822
        for offset in stride(from: CGFloat(0), through: 20_000, by: 37) {
            let window = ExplorerTreeWindow.around(offset: offset, viewport: viewport)
            #expect(window.minY <= offset)
            #expect(window.maxY >= offset + viewport + viewport / 8)
            #expect(window.minY >= 0)
        }
    }

    @Test func theWindowMovesOnlyInSteps() {
        let first = ExplorerTreeWindow.around(offset: 1_000, viewport: 800)
        #expect(ExplorerTreeWindow.around(offset: 1_050, viewport: 800) == first)
        #expect(ExplorerTreeWindow.around(offset: 1_100, viewport: 800) != first)
    }

    @Test func beforeTheViewIsMeasuredTheWindowStartsAtTheTop() {
        #expect(ExplorerTreeWindow.around(offset: 500, viewport: 0) == .initial)
    }

    @Test func intersectsIsOpenAtTheEdges() {
        let window = ExplorerTreeWindow(minY: 100, maxY: 200)
        #expect(window.intersects(minY: 150, maxY: 180))
        #expect(window.intersects(minY: 90, maxY: 101))
        #expect(!window.intersects(minY: 50, maxY: 100))
        #expect(!window.intersects(minY: 200, maxY: 250))
    }

    @Test func theHoldFollowsTheRowsHeight() {
        let scroll = ExplorerTreeScrollState()
        scroll.viewportHeight = 400
        scroll.totalHeight = 1_000
        scroll.offset = 600
        scroll.updateHold(contentHeight: 700)
        #expect(scroll.holdHeight == 300)
        scroll.updateHold(contentHeight: 1_000)
        #expect(scroll.holdHeight == 0)
    }
}
