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
        let vm = makeViewModel()
        #expect(vm.showCreateSnapshotSheet == false)
    }

    @Test func initialCreateSnapshotConnectionIDIsNil() {
        let vm = makeViewModel()
        #expect(vm.createSnapshotConnectionID == nil)
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
        let vm = makeViewModel()
        let connectionID = UUID()

        vm.createSnapshotConnectionID = connectionID
        vm.showCreateSnapshotSheet = true

        #expect(vm.showCreateSnapshotSheet == true)
        #expect(vm.createSnapshotConnectionID == connectionID)
    }

    @Test func dismissCreateSnapshotSheet() {
        let vm = makeViewModel()
        let connectionID = UUID()

        vm.createSnapshotConnectionID = connectionID
        vm.showCreateSnapshotSheet = true

        vm.showCreateSnapshotSheet = false
        #expect(vm.showCreateSnapshotSheet == false)
    }

    // MARK: - Detach Sheet State

    @Test func initialDetachSheetNotShown() {
        let vm = makeViewModel()
        #expect(vm.showDetachSheet == false)
        #expect(vm.detachDatabaseName == nil)
        #expect(vm.detachConnectionID == nil)
    }

    @Test func showDetachSheetSetsState() {
        let vm = makeViewModel()
        let connectionID = UUID()

        vm.detachDatabaseName = "AdventureWorks"
        vm.detachConnectionID = connectionID
        vm.showDetachSheet = true

        #expect(vm.showDetachSheet == true)
        #expect(vm.detachDatabaseName == "AdventureWorks")
        #expect(vm.detachConnectionID == connectionID)
    }

    // MARK: - Attach Sheet State

    @Test func initialAttachSheetNotShown() {
        let vm = makeViewModel()
        #expect(vm.showAttachSheet == false)
        #expect(vm.attachConnectionID == nil)
    }

    @Test func showAttachSheetSetsState() {
        let vm = makeViewModel()
        let connectionID = UUID()

        vm.attachConnectionID = connectionID
        vm.showAttachSheet = true

        #expect(vm.showAttachSheet == true)
        #expect(vm.attachConnectionID == connectionID)
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
