import Testing
@testable import Echo

@Suite("TuningAdvisorViewModel")
struct TuningAdvisorViewModelTests {

    @Test("Initial state has empty recommendations")
    @MainActor
    func initialState() {
        let vm = TuningAdvisorViewModel(tuningClient: nil, session: nil, connectionSessionID: .init())
        #expect(vm.recommendations.isEmpty)
        #expect(!vm.isRefreshing)
        #expect(!vm.isCreatingIndex)
        #expect(vm.selectedRecommendationID == nil)
        #expect(vm.errorMessage == nil)
    }

    @Test("selectedRecommendation returns nil when no selection")
    @MainActor
    func selectedRecommendationNilWithoutSelection() {
        let vm = TuningAdvisorViewModel(tuningClient: nil, session: nil, connectionSessionID: .init())
        #expect(vm.selectedRecommendation == nil)
    }

    @Test("refresh does nothing with nil client")
    @MainActor
    func refreshWithNilClient() {
        let vm = TuningAdvisorViewModel(tuningClient: nil, session: nil, connectionSessionID: .init())
        vm.refresh()
        #expect(!vm.isRefreshing)
    }

    @Test("createIndex does nothing with nil session")
    @MainActor
    func createIndexWithNilSession() async {
        let vm = TuningAdvisorViewModel(tuningClient: nil, session: nil, connectionSessionID: .init())
        await vm.createIndex(sql: "CREATE INDEX test ON dbo.test (col1)", indexName: "test")
        #expect(!vm.isCreatingIndex)
    }
}
