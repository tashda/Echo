import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("NewServiceSheet")
struct NewServiceSheetTests {

    // MARK: - Validation

    @Test func cannotCreateWithEmptyName() {
        #expect(NewServiceSheet.isCreateValid(name: "", queueName: "OrderQueue", isCreating: false) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyName() {
        #expect(NewServiceSheet.isCreateValid(name: "   ", queueName: "OrderQueue", isCreating: false) == false)
    }

    @Test func cannotCreateWithEmptyQueueName() {
        #expect(NewServiceSheet.isCreateValid(name: "OrderService", queueName: "", isCreating: false) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyQueueName() {
        #expect(NewServiceSheet.isCreateValid(name: "OrderService", queueName: "   ", isCreating: false) == false)
    }

    @Test func cannotCreateWhileAlreadyCreating() {
        #expect(NewServiceSheet.isCreateValid(name: "OrderService", queueName: "OrderQueue", isCreating: true) == false)
    }

    @Test func canCreateWithValidInputs() {
        #expect(NewServiceSheet.isCreateValid(name: "OrderService", queueName: "OrderQueue", isCreating: false) == true)
    }
}
