import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("Connection Dock Visibility Policy")
struct ConnectionDockVisibilityPolicyTests {
    private let connectionIDs = [UUID(), UUID(), UUID(), UUID(), UUID()]

    @Test func compactDockKeepsLeftColumnSelectionOnTheLeft() {
        let indices = ConnectionDockVisibilityPolicy.visibleIndices(
            connectionIDs: connectionIDs,
            selectedConnectionID: connectionIDs[2],
            showsAllConnections: false
        )

        #expect(indices == [2, 3])
    }

    @Test func compactDockKeepsRightColumnSelectionOnTheRight() {
        let indices = ConnectionDockVisibilityPolicy.visibleIndices(
            connectionIDs: connectionIDs,
            selectedConnectionID: connectionIDs[3],
            showsAllConnections: false
        )

        #expect(indices == [2, 3])
    }

    @Test func unpairedLastSelectionRemainsInTheLeftColumn() {
        let indices = ConnectionDockVisibilityPolicy.visibleIndices(
            connectionIDs: connectionIDs,
            selectedConnectionID: connectionIDs[4],
            showsAllConnections: false
        )

        #expect(indices == [4, 3])
    }

    @Test func compactDockFallsBackToFirstTwoWhenSelectionIsUnavailable() {
        let indices = ConnectionDockVisibilityPolicy.visibleIndices(
            connectionIDs: connectionIDs,
            selectedConnectionID: UUID(),
            showsAllConnections: false
        )

        #expect(indices == [0, 1])
    }

    @Test func expandedDockShowsEveryConnectionInOriginalOrder() {
        let indices = ConnectionDockVisibilityPolicy.visibleIndices(
            connectionIDs: connectionIDs,
            selectedConnectionID: connectionIDs[2],
            showsAllConnections: true
        )

        #expect(indices == [0, 1, 2, 3, 4])
    }

    @Test func compactDockDoesNotHideEitherOfTwoConnections() {
        let twoConnections = Array(connectionIDs.prefix(2))
        let indices = ConnectionDockVisibilityPolicy.visibleIndices(
            connectionIDs: twoConnections,
            selectedConnectionID: twoConnections[1],
            showsAllConnections: false
        )

        #expect(indices == [0, 1])
    }
}
