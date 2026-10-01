import AppKit
import Testing
@testable import Echo

@MainActor
@Suite("Result grid live columns")
struct ResultGridLiveColumnsTests {
    private typealias Coordinator = QueryResultsTableView.Coordinator
    private let visible = NSRect(x: 2000, y: 300, width: 900, height: 400)
    private let wideTable = NSRect(x: 0, y: 0, width: 11_000, height: 50_000)

    @Test func reachesHalfAScreenPastEachSide() {
        let live = Coordinator.liveRect(bounds: wideTable, visible: visible)
        #expect(live.minX == 1550)
        #expect(live.maxX == 3350)
        #expect(live.minY == visible.minY)
        #expect(live.height == visible.height)
    }

    @Test func staysInsideTheTable() {
        let atStart = NSRect(x: 0, y: 0, width: 900, height: 400)
        let live = Coordinator.liveRect(bounds: wideTable, visible: atStart)
        #expect(live.minX == 0)
        #expect(live.maxX == 1350)
    }

    @Test func aNarrowTableIsAllLive() {
        let narrow = NSRect(x: 0, y: 0, width: 600, height: 5_000)
        let live = Coordinator.liveRect(bounds: narrow, visible: NSRect(x: 0, y: 0, width: 600, height: 400))
        #expect(live.minX == 0)
        #expect(live.width == 600)
    }

    @Test func liveColumnsFollowTheVisibleRect() {
        let table = NSTableView(frame: NSRect(x: 0, y: 0, width: 10_000, height: 2_000))
        for index in 0..<100 {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c\(index)"))
            column.width = 100
            table.addTableColumn(column)
        }
        let live = table.columnIndexes(in: Coordinator.liveRect(bounds: table.bounds, visible: NSRect(x: 5_000, y: 0, width: 800, height: 400)))
        #expect(live.count < 20)
        #expect(live.contains(50))
        #expect(!live.contains(0))
        #expect(!live.contains(99))
    }
}

@MainActor
@Suite("Result grid column lookup")
struct ResultGridColumnLookupTests {
    @Test func positionsFollowTheColumnOrder() {
        let ids = ["data-a", "data-b", "data-c"].map { NSUserInterfaceItemIdentifier(rawValue: $0) }
        let positions = QueryResultsTableView.Coordinator.positions(of: ids)
        #expect(positions[ids[0]] == 0)
        #expect(positions[ids[2]] == 2)
        #expect(positions.count == 3)
    }

    @Test func aRepeatedIdentifierKeepsItsFirstPosition() {
        let ids = ["data-a", "data-a"].map { NSUserInterfaceItemIdentifier(rawValue: $0) }
        #expect(QueryResultsTableView.Coordinator.positions(of: ids)[ids[0]] == 0)
    }
}
