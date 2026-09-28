import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("Object Browser Expansion Policy")
struct ObjectBrowserExpansionPolicyTests {
    @Test func disabledSingleConnectionExpansionUsesOnlyTheServerTree() {
        let layoutMode = ObjectBrowserConnectionLayoutMode(expandOneConnectionAtATime: false)

        #expect(layoutMode == .multipleConnections)
        #expect(!layoutMode.showsConnectionDock)
        #expect(layoutMode.includesPendingConnectionsInOutline)
        #expect(layoutMode.showsServerNameInOutline)
    }

    @Test func enabledSingleConnectionExpansionUsesTheConnectionDock() {
        let layoutMode = ObjectBrowserConnectionLayoutMode(expandOneConnectionAtATime: true)

        #expect(layoutMode == .singleConnection)
        #expect(layoutMode.showsConnectionDock)
        #expect(!layoutMode.includesPendingConnectionsInOutline)
        #expect(!layoutMode.showsServerNameInOutline)
        #expect(
            layoutMode.outlineTopSpacerHeight(connectionDockHeight: SpacingTokens.none)
                == SpacingTokens.xs
        )
        #expect(
            layoutMode.outlineTopSpacerHeight(connectionDockHeight: 100)
                == 100 + SpacingTokens.xs
        )
    }

    @Test func multiConnectionTreeKeepsItsStandardTopInset() {
        let layoutMode = ObjectBrowserConnectionLayoutMode(expandOneConnectionAtATime: false)

        #expect(
            layoutMode.outlineTopSpacerHeight(connectionDockHeight: 100)
                == SpacingTokens.xs
        )
    }

    @Test func expandingServerWithCollapseEnabledRemovesOtherServerRootsOnly() {
        let viewModel = ObjectBrowserSidebarViewModel()
        let first = UUID()
        let second = UUID()
        let firstServer = ObjectBrowserSidebarViewModel.serverNodeID(connectionID: first)
        let secondServer = ObjectBrowserSidebarViewModel.serverNodeID(connectionID: second)
        let firstChild = ObjectBrowserSidebarViewModel.databasesFolderNodeID(connectionID: first)

        viewModel.expandedNodeIDs = [firstServer, firstChild]
        viewModel.setServerExpanded(
            true,
            connectionID: second,
            allConnectionIDs: [first, second],
            collapseOthers: true
        )

        #expect(!viewModel.expandedNodeIDs.contains(firstServer))
        #expect(viewModel.expandedNodeIDs.contains(secondServer))
        #expect(viewModel.expandedNodeIDs.contains(firstChild))
    }

    @Test func expandingServerWithCollapseDisabledPreservesOtherServerRoots() {
        let viewModel = ObjectBrowserSidebarViewModel()
        let first = UUID()
        let second = UUID()
        let firstServer = ObjectBrowserSidebarViewModel.serverNodeID(connectionID: first)
        let secondServer = ObjectBrowserSidebarViewModel.serverNodeID(connectionID: second)

        viewModel.expandedNodeIDs = [firstServer]
        viewModel.setServerExpanded(
            true,
            connectionID: second,
            allConnectionIDs: [first, second],
            collapseOthers: false
        )

        #expect(viewModel.expandedNodeIDs.contains(firstServer))
        #expect(viewModel.expandedNodeIDs.contains(secondServer))
    }

    @Test func collapsingServerOnlyRemovesThatServerRoot() {
        let viewModel = ObjectBrowserSidebarViewModel()
        let connectionID = UUID()
        let server = ObjectBrowserSidebarViewModel.serverNodeID(connectionID: connectionID)
        let child = ObjectBrowserSidebarViewModel.databasesFolderNodeID(connectionID: connectionID)

        viewModel.expandedNodeIDs = [server, child]
        viewModel.setServerExpanded(
            false,
            connectionID: connectionID,
            allConnectionIDs: [connectionID],
            collapseOthers: true
        )

        #expect(!viewModel.expandedNodeIDs.contains(server))
        #expect(viewModel.expandedNodeIDs.contains(child))
    }

}
