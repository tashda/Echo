import Testing
@testable import Echo

@Suite("AvailabilityGroupsViewModel")
struct AvailabilityGroupsViewModelTests {

    @Test("LoadingState equality")
    func loadingStateEquality() {
        #expect(AvailabilityGroupsViewModel.LoadingState.idle == .idle)
        #expect(AvailabilityGroupsViewModel.LoadingState.loading == .loading)
        #expect(AvailabilityGroupsViewModel.LoadingState.loaded == .loaded)
        #expect(AvailabilityGroupsViewModel.LoadingState.error("a") == .error("a"))
        #expect(AvailabilityGroupsViewModel.LoadingState.error("a") != .error("b"))
        #expect(AvailabilityGroupsViewModel.LoadingState.idle != .loading)
    }
}
