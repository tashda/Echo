import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("NewMessageTypeSheet")
struct NewMessageTypeSheetTests {

    // MARK: - Validation

    @Test func cannotCreateWithEmptyName() {
        #expect(NewMessageTypeSheet.isCreateValid(name: "", isCreating: false) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyName() {
        #expect(NewMessageTypeSheet.isCreateValid(name: "   ", isCreating: false) == false)
    }

    @Test func cannotCreateWhileAlreadyCreating() {
        #expect(NewMessageTypeSheet.isCreateValid(name: "OrderMessage", isCreating: true) == false)
    }

    @Test func canCreateWithValidName() {
        #expect(NewMessageTypeSheet.isCreateValid(name: "OrderMessage", isCreating: false) == true)
    }

    @Test func canCreateTrimsWhitespace() {
        #expect(NewMessageTypeSheet.isCreateValid(name: "  OrderMessage  ", isCreating: false) == true)
    }
}
