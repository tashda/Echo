import Testing
@testable import Echo

@Suite("PolicyManagementViewModel")
struct PolicyManagementViewModelTests {

    @Test("PolicyTab has all expected cases")
    func policyTabCases() {
        let allCases = PolicyManagementViewModel.PolicyTab.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.policies))
        #expect(allCases.contains(.conditions))
        #expect(allCases.contains(.facets))
        #expect(allCases.contains(.history))
    }

    @Test("PolicyTab raw values match display text")
    func policyTabRawValues() {
        #expect(PolicyManagementViewModel.PolicyTab.policies.rawValue == "Policies")
        #expect(PolicyManagementViewModel.PolicyTab.conditions.rawValue == "Conditions")
        #expect(PolicyManagementViewModel.PolicyTab.facets.rawValue == "Facets")
        #expect(PolicyManagementViewModel.PolicyTab.history.rawValue == "History")
    }

    @Test("Initial state has empty collections and default tab")
    @MainActor
    func initialState() {
        let vm = PolicyManagementViewModel(policyClient: nil, connectionSessionID: .init())
        #expect(vm.policies.isEmpty)
        #expect(vm.conditions.isEmpty)
        #expect(vm.facets.isEmpty)
        #expect(vm.history.isEmpty)
        #expect(!vm.isRefreshing)
        #expect(vm.selectedPolicyID == nil)
        #expect(vm.selectedTab == .policies)
    }

    @Test("selectedPolicy returns nil when no selection")
    @MainActor
    func selectedPolicyNilWithoutSelection() {
        let vm = PolicyManagementViewModel(policyClient: nil, connectionSessionID: .init())
        #expect(vm.selectedPolicy == nil)
    }

    @Test("refresh does nothing with nil client")
    @MainActor
    func refreshWithNilClient() {
        let vm = PolicyManagementViewModel(policyClient: nil, connectionSessionID: .init())
        vm.refresh()
        #expect(!vm.isRefreshing)
    }
}
