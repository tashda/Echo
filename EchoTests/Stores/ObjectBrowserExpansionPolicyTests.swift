import Foundation
import Testing
@testable import Echo

/// Cards open and close independently, and a minimized card leaves the tree (round 51, SH5).
@MainActor
@Suite("Object Browser Expansion Policy")
struct ObjectBrowserExpansionPolicyTests {
    private func serverID(_ id: UUID) -> String {
        ObjectBrowserSidebarViewModel.serverNodeID(connectionID: id)
    }

    @Test func expandingAServerLeavesOtherServersAlone() {
        let viewModel = ObjectBrowserSidebarViewModel()
        let first = UUID()
        let second = UUID()
        viewModel.expandedNodeIDs = [serverID(first)]

        viewModel.setServerExpanded(true, connectionID: second)

        #expect(viewModel.expandedNodeIDs.contains(serverID(first)))
        #expect(viewModel.expandedNodeIDs.contains(serverID(second)))
    }

    @Test func minimizingAServerOnlyRemovesThatServerRoot() {
        let viewModel = ObjectBrowserSidebarViewModel()
        let connectionID = UUID()
        let child = ObjectBrowserSidebarViewModel.databasesFolderNodeID(connectionID: connectionID)
        viewModel.expandedNodeIDs = [serverID(connectionID), child]

        viewModel.setServerExpanded(false, connectionID: connectionID)

        #expect(!viewModel.expandedNodeIDs.contains(serverID(connectionID)))
        #expect(viewModel.expandedNodeIDs.contains(child))
    }

    @Test func a_minimized_server_is_one_that_was_set_up_and_is_not_expanded() {
        let open = UUID()
        let minimized = UUID()
        let notSetUpYet = UUID()
        let state = ExplorerMinimizedServers(
            sessionConnectionIDs: [open, minimized, notSetUpYet],
            initializedConnectionIDs: [open, minimized],
            expandedNodeIDs: [serverID(open)]
        )

        #expect(state.connectionIDs == [minimized])
        #expect(state.isMinimized(minimized))
        #expect(!state.isMinimized(open))
        #expect(!state.isMinimized(notSetUpYet))
    }

    @Test func minimized_servers_leave_the_list_and_the_rest_keep_their_order() {
        let a = UUID(), b = UUID(), c = UUID()
        let state = ExplorerMinimizedServers(
            sessionConnectionIDs: [a, b, c],
            initializedConnectionIDs: [a, b, c],
            expandedNodeIDs: [serverID(a), serverID(c)]
        )

        #expect(state.shown(from: [a, b, c]) == [a, c])
    }

    @Test func restoring_a_minimized_server_brings_it_back_into_the_list() {
        let viewModel = ObjectBrowserSidebarViewModel()
        let a = UUID(), b = UUID()
        viewModel.initializedConnectionIDs = [a, b]
        viewModel.expandedNodeIDs = [serverID(a)]

        let before = ExplorerMinimizedServers(
            sessionConnectionIDs: [a, b], initializedConnectionIDs: [a, b], expandedNodeIDs: viewModel.expandedNodeIDs
        )
        #expect(before.shown(from: [a, b]) == [a])

        viewModel.setServerExpanded(true, connectionID: b)
        let after = ExplorerMinimizedServers(
            sessionConnectionIDs: [a, b], initializedConnectionIDs: [a, b], expandedNodeIDs: viewModel.expandedNodeIDs
        )
        #expect(after.connectionIDs.isEmpty)
        #expect(after.shown(from: [a, b]) == [a, b])
    }

    @Test func the_tree_is_empty_only_when_every_server_is_minimized_and_nothing_is_connecting() {
        let a = UUID(), b = UUID()
        let allMinimized = ExplorerMinimizedServers(
            sessionConnectionIDs: [a, b], initializedConnectionIDs: [a, b], expandedNodeIDs: []
        )
        let oneOpen = ExplorerMinimizedServers(
            sessionConnectionIDs: [a, b], initializedConnectionIDs: [a, b], expandedNodeIDs: [serverID(a)]
        )

        #expect(allMinimized.leavesTreeEmpty(sessionConnectionIDs: [a, b], pendingCount: 0))
        #expect(!allMinimized.leavesTreeEmpty(sessionConnectionIDs: [a, b], pendingCount: 1))
        #expect(!oneOpen.leavesTreeEmpty(sessionConnectionIDs: [a, b], pendingCount: 0))
        #expect(!allMinimized.leavesTreeEmpty(sessionConnectionIDs: [], pendingCount: 0))
    }

    @Test func new_servers_open_and_never_open_one_at_a_time() {
        let viewModel = ObjectBrowserSidebarViewModel()
        let a = UUID(), b = UUID()
        viewModel.setServerExpanded(true, connectionID: a)
        viewModel.setServerExpanded(true, connectionID: b)

        #expect(viewModel.expandedNodeIDs == [serverID(a), serverID(b)])
    }

    /// The old setting is gone; a stored value for it is ignored, not an error.
    @Test func settings_saved_with_the_old_one_at_a_time_key_still_decode() throws {
        let json = #"{"sidebarExpandOneConnectionAtATime": false, "sidebarShowsScrollBar": true}"#
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: Data(json.utf8))

        #expect(decoded.sidebarShowsScrollBar)
    }
}
