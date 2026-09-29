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

    private func snapshotsKey(_ connectionID: UUID = UUID()) -> ExplorerSourceKey {
        ExplorerSourceKey(connectionID: connectionID, source: .databaseSnapshots)
    }

    @Test func initialSnapshotsDataIsEmpty() {
        let vm = makeViewModel()
        let key = snapshotsKey()
        #expect(vm.childSources.isEmpty)
        #expect(vm.items(key, kind: .databaseSnapshots).isEmpty)
        #expect(vm.sourceState(key).needsLoad)
    }

    @Test func initialCreateSnapshotSheetNotShown() {
        let state = makeSheetState()
        #expect(state.showCreateSnapshotSheet == false)
    }

    @Test func initialCreateSnapshotConnectionIDIsNil() {
        let state = makeSheetState()
        #expect(state.createSnapshotConnectionID == nil)
    }

    // MARK: - Snapshot Folder Expansion

    @Test func expandSnapshotsFolderForSession() {
        let vm = makeViewModel()
        let folderID = ObjectBrowserSidebarViewModel.serverFolderNodeID(connectionID: UUID(), kind: .databaseSnapshots)

        vm.setExpanded(true, nodeID: folderID)
        #expect(vm.isExpanded(folderID))
        vm.setExpanded(false, nodeID: folderID)
        #expect(!vm.isExpanded(folderID))
    }

    @Test func snapshotsFolderKeepsItsSavedID() {
        let connectionID = UUID()
        #expect(
            ObjectBrowserSidebarViewModel.serverFolderNodeID(connectionID: connectionID, kind: .databaseSnapshots)
                == "\(connectionID.uuidString)#server-folder#databaseSnapshots"
        )
    }

    // MARK: - Snapshot Loading State

    @Test func beginLoadingMarksTheSourceLoading() {
        let vm = makeViewModel()
        let key = snapshotsKey()

        vm.beginLoading(key)
        #expect(vm.sourceState(key).isLoading)
        #expect(!vm.sourceState(key).needsLoad)
    }

    @Test func finishLoadingStoresItemsAndStopsLoading() {
        let vm = makeViewModel()
        let key = snapshotsKey()

        vm.beginLoading(key)
        vm.finishLoading(key, items: [.databaseSnapshots: [ExplorerItem(id: "snap1", name: "snap1", detail: "AdventureWorks")]])
        #expect(!vm.sourceState(key).isLoading)
        #expect(vm.sourceState(key).hasLoaded)
        #expect(vm.items(key, kind: .databaseSnapshots).map(\.name) == ["snap1"])
    }

    @Test func endLoadingStopsWithoutMarkingLoaded() {
        let vm = makeViewModel()
        let key = snapshotsKey()

        vm.beginLoading(key)
        vm.endLoading(key)
        #expect(!vm.sourceState(key).isLoading)
        #expect(vm.sourceState(key).needsLoad)
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
        let first = snapshotsKey()
        let second = snapshotsKey()

        vm.beginLoading(second)
        vm.finishLoading(first, items: [.databaseSnapshots: [ExplorerItem(id: "a", name: "a")]])

        #expect(!vm.sourceState(first).isLoading)
        #expect(vm.sourceState(second).isLoading)
        #expect(vm.items(first, kind: .databaseSnapshots).count == 1)
        #expect(vm.items(second, kind: .databaseSnapshots).isEmpty)
    }
}
