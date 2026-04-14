import Testing
@testable import Echo

@Suite("ResourceGovernorViewModel")
struct ResourceGovernorViewModelTests {

    @Test("Initial state has nil configuration and empty collections")
    @MainActor
    func initialState() {
        let vm = ResourceGovernorViewModel(rgClient: nil, connectionSessionID: .init())
        #expect(vm.configuration == nil)
        #expect(vm.pools.isEmpty)
        #expect(vm.groups.isEmpty)
        #expect(!vm.isRefreshing)
        #expect(!vm.isToggling)
        #expect(vm.errorMessage == nil)
        #expect(vm.selectedPoolID == nil)
        #expect(vm.selectedGroupID == nil)
    }

    @Test("selectedPool returns nil when no selection")
    @MainActor
    func selectedPoolNilWithoutSelection() {
        let vm = ResourceGovernorViewModel(rgClient: nil, connectionSessionID: .init())
        #expect(vm.selectedPool == nil)
    }

    @Test("selectedGroup returns nil when no selection")
    @MainActor
    func selectedGroupNilWithoutSelection() {
        let vm = ResourceGovernorViewModel(rgClient: nil, connectionSessionID: .init())
        #expect(vm.selectedGroup == nil)
    }

    @Test("refresh does nothing with nil client")
    @MainActor
    func refreshWithNilClient() {
        let vm = ResourceGovernorViewModel(rgClient: nil, connectionSessionID: .init())
        vm.refresh()
        #expect(!vm.isRefreshing)
    }

    @Test("toggleEnabled does nothing with nil client")
    @MainActor
    func toggleWithNilClient() async {
        let vm = ResourceGovernorViewModel(rgClient: nil, connectionSessionID: .init())
        await vm.toggleEnabled()
        #expect(!vm.isToggling)
    }
}
