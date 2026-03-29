import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("DatabaseSnapshotsSidebar")
struct DatabaseSnapshotsSidebarTests {

    // MARK: - Factory

    private func makeViewModel() -> ObjectBrowserSidebarViewModel {
        ObjectBrowserSidebarViewModel()
    }

    private func makeSheetState() -> SidebarSheetState {
        SidebarSheetState()
    }

    // MARK: - Initial Snapshot State

    @Test func initialSnapshotsExpandedIsEmpty() {
        let vm = makeViewModel()
        #expect(vm.databaseSnapshotsExpandedBySession.isEmpty)
    }

    @Test func initialSnapshotsDataIsEmpty() {
        let vm = makeViewModel()
        #expect(vm.databaseSnapshotsBySession.isEmpty)
    }

    @Test func initialSnapshotsLoadingIsEmpty() {
        let vm = makeViewModel()
        #expect(vm.databaseSnapshotsLoadingBySession.isEmpty)
    }

    @Test func initialCreateSnapshotSheetNotShown() {
        let state = makeSheetState()
        #expect(state.showCreateSnapshotSheet == false)
    }

    @Test func initialCreateSnapshotConnectionIDIsNil() {
        let state = makeSheetState()
        #expect(state.createSnapshotConnectionID == nil)
    }

    // MARK: - Snapshot Expansion Toggle

    @Test func expandSnapshotsForSession() {
        let vm = makeViewModel()
        let sessionID = UUID()

        vm.databaseSnapshotsExpandedBySession[sessionID] = true
        #expect(vm.databaseSnapshotsExpandedBySession[sessionID] == true)
    }

    @Test func collapseSnapshotsForSession() {
        let vm = makeViewModel()
        let sessionID = UUID()

        vm.databaseSnapshotsExpandedBySession[sessionID] = true
        vm.databaseSnapshotsExpandedBySession[sessionID] = false
        #expect(vm.databaseSnapshotsExpandedBySession[sessionID] == false)
    }

    @Test func unexpandedSessionDefaultsToFalse() {
        let vm = makeViewModel()
        let sessionID = UUID()

        let isExpanded = vm.databaseSnapshotsExpandedBySession[sessionID] ?? false
        #expect(isExpanded == false)
    }

    // MARK: - Snapshot Loading State

    @Test func setSnapshotsLoadingForSession() {
        let vm = makeViewModel()
        let sessionID = UUID()

        vm.databaseSnapshotsLoadingBySession[sessionID] = true
        #expect(vm.databaseSnapshotsLoadingBySession[sessionID] == true)
    }

    @Test func clearSnapshotsLoadingForSession() {
        let vm = makeViewModel()
        let sessionID = UUID()

        vm.databaseSnapshotsLoadingBySession[sessionID] = true
        vm.databaseSnapshotsLoadingBySession[sessionID] = false
        #expect(vm.databaseSnapshotsLoadingBySession[sessionID] == false)
    }

    @Test func unsetLoadingSessionDefaultsToFalse() {
        let vm = makeViewModel()
        let sessionID = UUID()

        let isLoading = vm.databaseSnapshotsLoadingBySession[sessionID] ?? false
        #expect(isLoading == false)
    }

    // MARK: - Create Snapshot Sheet State

    @Test func showCreateSnapshotSheetToggles() {
        let state = makeSheetState()
        let connectionID = UUID()

        state.createSnapshotConnectionID = connectionID
        state.showCreateSnapshotSheet = true

        #expect(state.showCreateSnapshotSheet == true)
        #expect(state.createSnapshotConnectionID == connectionID)
    }

    @Test func dismissCreateSnapshotSheet() {
        let state = makeSheetState()
        let connectionID = UUID()

        state.createSnapshotConnectionID = connectionID
        state.showCreateSnapshotSheet = true

        state.showCreateSnapshotSheet = false
        #expect(state.showCreateSnapshotSheet == false)
    }

    // MARK: - Detach Sheet State

    @Test func initialDetachSheetNotShown() {
        let state = makeSheetState()
        #expect(state.showDetachSheet == false)
        #expect(state.detachDatabaseName == nil)
        #expect(state.detachConnectionID == nil)
    }

    @Test func showDetachSheetSetsState() {
        let state = makeSheetState()
        let connectionID = UUID()

        state.detachDatabaseName = "AdventureWorks"
        state.detachConnectionID = connectionID
        state.showDetachSheet = true

        #expect(state.showDetachSheet == true)
        #expect(state.detachDatabaseName == "AdventureWorks")
        #expect(state.detachConnectionID == connectionID)
    }

    // MARK: - Attach Sheet State

    @Test func initialAttachSheetNotShown() {
        let state = makeSheetState()
        #expect(state.showAttachSheet == false)
        #expect(state.attachConnectionID == nil)
    }

    @Test func showAttachSheetSetsState() {
        let state = makeSheetState()
        let connectionID = UUID()

        state.attachConnectionID = connectionID
        state.showAttachSheet = true

        #expect(state.showAttachSheet == true)
        #expect(state.attachConnectionID == connectionID)
    }

    // MARK: - Multiple Sessions Independence

    @Test func snapshotStateIsIndependentPerSession() {
        let vm = makeViewModel()
        let session1 = UUID()
        let session2 = UUID()

        vm.databaseSnapshotsExpandedBySession[session1] = true
        vm.databaseSnapshotsExpandedBySession[session2] = false
        vm.databaseSnapshotsLoadingBySession[session1] = false
        vm.databaseSnapshotsLoadingBySession[session2] = true

        #expect(vm.databaseSnapshotsExpandedBySession[session1] == true)
        #expect(vm.databaseSnapshotsExpandedBySession[session2] == false)
        #expect(vm.databaseSnapshotsLoadingBySession[session1] == false)
        #expect(vm.databaseSnapshotsLoadingBySession[session2] == true)
    }
}
