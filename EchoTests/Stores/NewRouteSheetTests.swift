import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("NewRouteSheet")
struct NewRouteSheetTests {

    // MARK: - Validation

    @Test func cannotCreateWithEmptyName() {
        #expect(NewRouteSheet.isCreateValid(name: "", address: "TCP://server:4022", isCreating: false) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyName() {
        #expect(NewRouteSheet.isCreateValid(name: "   ", address: "TCP://server:4022", isCreating: false) == false)
    }

    @Test func cannotCreateWithEmptyAddress() {
        #expect(NewRouteSheet.isCreateValid(name: "OrderRoute", address: "", isCreating: false) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyAddress() {
        #expect(NewRouteSheet.isCreateValid(name: "OrderRoute", address: "   ", isCreating: false) == false)
    }

    @Test func cannotCreateWhileAlreadyCreating() {
        #expect(NewRouteSheet.isCreateValid(name: "OrderRoute", address: "TCP://server:4022", isCreating: true) == false)
    }

    @Test func canCreateWithValidInputs() {
        #expect(NewRouteSheet.isCreateValid(name: "OrderRoute", address: "TCP://server:4022", isCreating: false) == true)
    }
}
