import Foundation
import Testing
@testable import Echo

/// Round IC: one column, four pages, one rule for every way in.
@Suite("Inspector column: pages and ways in")
@MainActor
struct InspectorColumnModeTests {
    private func state() -> AppState {
        AppState(historyDefaults: UserDefaults(suiteName: "InspectorColumnModeTests.\(UUID().uuidString)")!)
    }

    @Test func bellOpensNotificationsThenClosesTheColumn() {
        let state = state()
        state.toggleNotificationHistory()
        #expect(state.isInspectorColumnVisible)
        #expect(state.inspectorPage == .notifications)
        #expect(!state.showInfoSidebar)
        state.toggleNotificationHistory()
        #expect(!state.isInspectorColumnVisible)
    }

    @Test func bellSwitchesFromAnotherPage() {
        let state = state()
        state.showInspectorPage(.bookmarks)
        state.toggleNotificationHistory()
        #expect(state.isNotificationHistoryVisible)
    }

    @Test func inspectorButtonClosesFromAnyPageAndReopensOnIt() {
        let state = state()
        state.showInspectorPage(.history)
        state.toggleInspector()
        #expect(!state.isInspectorColumnVisible)
        state.toggleInspector()
        #expect(state.isInspectorColumnVisible)
        #expect(state.inspectorPage == .history)
    }

    @Test func askingForTheShownPageClosesTheColumn() {
        let state = state()
        state.toggleInspectorPage(.bookmarks)
        #expect(state.inspectorPage == .bookmarks && state.isInspectorColumnVisible)
        state.toggleInspectorPage(.history)
        #expect(state.inspectorPage == .history && state.isInspectorColumnVisible)
        state.toggleInspectorPage(.history)
        #expect(!state.isInspectorColumnVisible)
    }

    @Test func askingForDetailsSwitchesFromAnyPage() {
        let state = state()
        state.showNotificationHistory()
        state.showInfoSidebar = true
        #expect(state.inspectorPage == .details)
        #expect(!state.isNotificationHistoryVisible)
    }

    @Test func hidingDetailsLeavesOtherPagesAlone() {
        let state = state()
        state.showInspectorPage(.bookmarks)
        state.showInfoSidebar = false
        #expect(state.isInspectorColumnVisible)
    }

    @Test func passiveSelectionOpensAClosedColumnOnDetails() {
        let state = state()
        #expect(state.noteDetailsChanged(autoOpen: true))
        #expect(state.showInfoSidebar)
        #expect(!state.hasUnseenDetails)
    }

    @Test func passiveSelectionWithoutAutoOpenLeavesItClosed() {
        let state = state()
        #expect(!state.noteDetailsChanged(autoOpen: false))
        #expect(!state.isInspectorColumnVisible)
    }

    @Test func passiveSelectionNeverTakesAnotherPageAway() {
        let state = state()
        state.showInspectorPage(.history)
        #expect(!state.noteDetailsChanged(autoOpen: true))
        #expect(state.inspectorPage == .history)
        #expect(state.hasUnseenDetails)
        state.showInspectorPage(.details)
        #expect(!state.hasUnseenDetails)
    }

    @Test func thePageIsRemembered() {
        let defaults = UserDefaults(suiteName: "InspectorColumnModeTests.remember.\(UUID().uuidString)")!
        AppState(historyDefaults: defaults).showInspectorPage(.bookmarks)
        #expect(AppState(historyDefaults: defaults).inspectorPage == .bookmarks)
    }
}
