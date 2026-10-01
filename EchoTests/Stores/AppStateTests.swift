import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("AppState")
struct AppStateTests {
    private func isolatedState() -> AppState {
        AppState(historyDefaults: UserDefaults(suiteName: "AppStateTests.\(UUID())")!)
    }


    // MARK: - showError

    @Test func showErrorSetsErrorAndFlag() {
        let state = isolatedState()
        let error = DatabaseError.connectionFailed("timeout")

        state.showError(error)

        #expect(state.currentError != nil)
        #expect(state.showingError == true)
    }

    @Test func showErrorClearsLoadingStates() {
        let state = isolatedState()
        state.isLoading = true
        state.isConnecting = true
        state.isQueryRunning = true

        state.showError(.queryError("failed"))

        #expect(state.isLoading == false)
        #expect(state.isConnecting == false)
        #expect(state.isQueryRunning == false)
    }

    @Test func showErrorOverridesPreviousError() {
        let state = isolatedState()
        state.showError(.connectionFailed("first"))
        state.showError(.queryError("second"))

        if case .queryError(let msg, _) = state.currentError {
            #expect(msg == "second")
        } else {
            Issue.record("Expected queryError")
        }
    }

    // MARK: - clearError

    @Test func clearErrorClearsBoth() {
        let state = isolatedState()
        state.showError(.connectionFailed("test"))

        state.clearError()

        #expect(state.currentError == nil)
        #expect(state.showingError == false)
    }

    @Test func clearErrorWhenAlreadyClearIsNoOp() {
        let state = isolatedState()
        state.clearError()

        #expect(state.currentError == nil)
        #expect(state.showingError == false)
    }

    // MARK: - startLoading / stopLoading

    @Test func startLoadingSetsFlag() {
        let state = isolatedState()
        state.startLoading()
        #expect(state.isLoading == true)
    }

    @Test func stopLoadingClearsFlag() {
        let state = isolatedState()
        state.startLoading()
        state.stopLoading()
        #expect(state.isLoading == false)
    }

    @Test func stopLoadingWhenNotLoadingIsNoOp() {
        let state = isolatedState()
        state.stopLoading()
        #expect(state.isLoading == false)
    }

    // MARK: - showSheet / dismissSheet

    @Test func showSheetSetsActiveSheet() {
        let state = isolatedState()
        state.showSheet(.connectionEditor)
        #expect(state.activeSheet == .connectionEditor)
    }

    @Test func showSheetReplacesExisting() {
        let state = isolatedState()
        state.showSheet(.connectionEditor)
        state.showSheet(.preferences)
        #expect(state.activeSheet == .preferences)
    }

    @Test func dismissSheetClearsActiveSheet() {
        let state = isolatedState()
        state.showSheet(.about)
        state.dismissSheet()
        #expect(state.activeSheet == nil)
    }

    @Test func dismissSheetWhenNoSheetIsNoOp() {
        let state = isolatedState()
        state.dismissSheet()
        #expect(state.activeSheet == nil)
    }

    @Test func showSheetAllCases() {
        let state = isolatedState()
        let cases: [ActiveSheet] = [.connectionEditor, .quickConnect, .preferences, .about, .exportData]
        for sheet in cases {
            state.showSheet(sheet)
            #expect(state.activeSheet == sheet)
        }
    }

    // MARK: - addToQueryHistory

    @Test func addToQueryHistoryAddsItem() {
        let state = isolatedState()
        state.clearQueryHistory()

        state.addToQueryHistory("SELECT 1;", resultCount: 1, duration: 0.5)

        #expect(state.queryHistory.count == 1)
        #expect(state.queryHistory[0].query == "SELECT 1;")
        #expect(state.queryHistory[0].resultCount == 1)
        #expect(state.queryHistory[0].duration == 0.5)
    }

    @Test func addToQueryHistoryInsertsAtFront() {
        let state = isolatedState()
        state.clearQueryHistory()

        state.addToQueryHistory("SELECT 1;")
        state.addToQueryHistory("SELECT 2;")

        #expect(state.queryHistory[0].query == "SELECT 2;")
        #expect(state.queryHistory[1].query == "SELECT 1;")
    }

    @Test func addToQueryHistoryKeepsMoreThan500ByDefault() {
        let state = isolatedState()
        state.clearQueryHistory()

        for i in 0..<510 {
            state.addToQueryHistory("SELECT \(i);")
        }

        #expect(state.queryHistory.count == 510)
        // Most recent should be at index 0
        #expect(state.queryHistory[0].query == "SELECT 509;")
    }

    @Test func addToQueryHistoryWithNilOptionals() {
        let state = isolatedState()
        state.clearQueryHistory()

        state.addToQueryHistory("SELECT 1;")

        #expect(state.queryHistory[0].resultCount == nil)
        #expect(state.queryHistory[0].duration == nil)
    }

    // MARK: - clearQueryHistory

    @Test func clearQueryHistoryEmptiesList() {
        let state = isolatedState()
        state.addToQueryHistory("SELECT 1;")
        state.addToQueryHistory("SELECT 2;")

        state.clearQueryHistory()

        #expect(state.queryHistory.isEmpty)
    }

    @Test func clearQueryHistoryWhenAlreadyEmptyIsNoOp() {
        let state = isolatedState()
        state.clearQueryHistory()
        state.clearQueryHistory()
        #expect(state.queryHistory.isEmpty)
    }

    // MARK: - QueryHistoryItem

    @Test func queryHistoryItemFormattedTimestamp() {
        let item = QueryHistoryItem(query: "SELECT 1;", timestamp: Date())

        let formatted = item.formattedTimestamp
        #expect(!formatted.isEmpty)
    }

    @Test func queryHistoryItemFormattedDurationWithValue() {
        let item = QueryHistoryItem(query: "SELECT 1;", timestamp: Date(), duration: 1.234)

        #expect(item.formattedDuration == "1.234s")
    }

    @Test func queryHistoryItemFormattedDurationNil() {
        let item = QueryHistoryItem(query: "SELECT 1;", timestamp: Date(), duration: nil)

        #expect(item.formattedDuration == nil)
    }

    @Test func queryHistoryItemFormattedDurationSmallValue() {
        let item = QueryHistoryItem(query: "SELECT 1;", timestamp: Date(), duration: 0.001)

        #expect(item.formattedDuration == "0.001s")
    }

    @Test func queryHistoryItemFormattedDurationZero() {
        let item = QueryHistoryItem(query: "SELECT 1;", timestamp: Date(), duration: 0.0)

        #expect(item.formattedDuration == "0.000s")
    }

    @Test func queryHistoryItemHasUniqueID() {
        let item1 = QueryHistoryItem(query: "SELECT 1;", timestamp: Date())
        let item2 = QueryHistoryItem(query: "SELECT 1;", timestamp: Date())

        #expect(item1.id != item2.id)
    }

    @Test func queryHistoryItemCodableRoundTrip() throws {
        let item = QueryHistoryItem(query: "SELECT * FROM users;", timestamp: Date(), resultCount: 42, duration: 0.567)

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(QueryHistoryItem.self, from: data)

        #expect(decoded.id == item.id)
        #expect(decoded.query == item.query)
        #expect(decoded.resultCount == item.resultCount)
        #expect(decoded.duration == item.duration)
    }

    // MARK: - ActiveSheet.id

    @Test func activeSheetIdMatchesRawValue() {
        #expect(ActiveSheet.connectionEditor.id == "connectionEditor")
        #expect(ActiveSheet.quickConnect.id == "quickConnect")
        #expect(ActiveSheet.preferences.id == "preferences")
        #expect(ActiveSheet.about.id == "about")
        #expect(ActiveSheet.exportData.id == "exportData")
    }

    @Test func activeSheetIdIsUnique() {
        let allCases: [ActiveSheet] = [.connectionEditor, .quickConnect, .preferences, .about, .exportData]
        let ids = Set(allCases.map(\.id))
        #expect(ids.count == allCases.count)
    }

    // MARK: - Initial state

    @Test func initialStateDefaults() {
        let state = isolatedState()

        #expect(state.isLoading == false)
        #expect(state.currentError == nil)
        #expect(state.showingError == false)
        #expect(state.activeSheet == nil)
        #expect(state.isTabOverviewVisible == false)
        #expect(state.showInfoSidebar == false)
        #expect(state.isQueryRunning == false)
        #expect(state.isConnecting == false)
    }
}
