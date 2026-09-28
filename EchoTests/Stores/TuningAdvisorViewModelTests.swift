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
        #expect(vm.loadErrorMessage == nil)
        #expect(!vm.hasLoadedRecommendations)
        #expect(!vm.hasLoadedIndexUsage)
    }

    @Test("selectedRecommendation returns nil when no selection")
    @MainActor
    func selectedRecommendationNilWithoutSelection() {
        let vm = TuningAdvisorViewModel(tuningClient: nil, session: nil, connectionSessionID: .init())
        #expect(vm.selectedRecommendation == nil)
    }

    @Test("refresh reports an unavailable client")
    @MainActor
    func refreshWithNilClient() {
        let vm = TuningAdvisorViewModel(tuningClient: nil, session: nil, connectionSessionID: .init())
        vm.refresh()
        #expect(!vm.isRefreshing)
        #expect(vm.loadErrorMessage != nil)
    }

    @Test("createIndex does nothing with nil session")
    @MainActor
    func createIndexWithNilSession() async {
        let vm = TuningAdvisorViewModel(tuningClient: nil, session: nil, connectionSessionID: .init())
        await vm.createIndex(sql: "CREATE INDEX test ON dbo.test (col1)", indexName: "test")
        #expect(!vm.isCreatingIndex)
    }
}
