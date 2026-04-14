import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("NewQueueSheet")
struct NewQueueSheetTests {

    // MARK: - Validation

    @Test func cannotCreateWithEmptyName() {
        #expect(NewQueueSheet.isCreateValid(name: "", isCreating: false) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyName() {
        #expect(NewQueueSheet.isCreateValid(name: "   ", isCreating: false) == false)
    }

    @Test func cannotCreateWhileAlreadyCreating() {
        #expect(NewQueueSheet.isCreateValid(name: "OrderQueue", isCreating: true) == false)
    }

    @Test func canCreateWithValidName() {
        #expect(NewQueueSheet.isCreateValid(name: "OrderQueue", isCreating: false) == true)
    }

    @Test func canCreateTrimsWhitespace() {
        #expect(NewQueueSheet.isCreateValid(name: "  OrderQueue  ", isCreating: false) == true)
    }
}
