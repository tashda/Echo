import Testing
@testable import Echo

@Suite("TuningAdvisorViewModel Tabs")
struct TuningAdvisorTabTests {

    @Test("TuningTab has expected cases")
    func tuningTabCases() {
        let allCases = TuningAdvisorViewModel.TuningTab.allCases
        #expect(allCases.count == 2)
        #expect(allCases.contains(.missingIndexes))
        #expect(allCases.contains(.indexUsage))
    }

    @Test("TuningTab raw values match display text")
    func tuningTabRawValues() {
        #expect(TuningAdvisorViewModel.TuningTab.missingIndexes.rawValue == "Missing Indexes")
        #expect(TuningAdvisorViewModel.TuningTab.indexUsage.rawValue == "Index Usage")
    }

    @Test("Default tab is missingIndexes")
    @MainActor
    func defaultTab() {
        let vm = TuningAdvisorViewModel(tuningClient: nil, session: nil, connectionSessionID: .init())
        #expect(vm.selectedTab == .missingIndexes)
        #expect(vm.indexUsageStats.isEmpty)
    }

    @Test("loadIndexUsageStats does nothing with nil client")
    @MainActor
    func loadIndexUsageStatsNilClient() {
        let vm = TuningAdvisorViewModel(tuningClient: nil, session: nil, connectionSessionID: .init())
        vm.loadIndexUsageStats()
        #expect(!vm.isRefreshing)
        #expect(vm.indexUsageStats.isEmpty)
    }
}
