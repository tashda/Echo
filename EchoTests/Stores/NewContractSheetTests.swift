import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("NewContractSheet")
struct NewContractSheetTests {

    // MARK: - Validation

    @Test func cannotCreateWithEmptyName() {
        #expect(NewContractSheet.isCreateValid(
            name: "",
            messageUsages: [(id: UUID(), messageType: "OrderMessage", sentBy: "INITIATOR")],
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyName() {
        #expect(NewContractSheet.isCreateValid(
            name: "   ",
            messageUsages: [(id: UUID(), messageType: "OrderMessage", sentBy: "INITIATOR")],
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWithEmptyUsages() {
        #expect(NewContractSheet.isCreateValid(
            name: "OrderContract",
            messageUsages: [],
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWithEmptyMessageType() {
        #expect(NewContractSheet.isCreateValid(
            name: "OrderContract",
            messageUsages: [(id: UUID(), messageType: "", sentBy: "INITIATOR")],
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyMessageType() {
        #expect(NewContractSheet.isCreateValid(
            name: "OrderContract",
            messageUsages: [(id: UUID(), messageType: "   ", sentBy: "INITIATOR")],
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWhileAlreadyCreating() {
        #expect(NewContractSheet.isCreateValid(
            name: "OrderContract",
            messageUsages: [(id: UUID(), messageType: "OrderMessage", sentBy: "INITIATOR")],
            isCreating: true
        ) == false)
    }

    @Test func canCreateWithValidInputs() {
        #expect(NewContractSheet.isCreateValid(
            name: "OrderContract",
            messageUsages: [(id: UUID(), messageType: "OrderMessage", sentBy: "INITIATOR")],
            isCreating: false
        ) == true)
    }

    @Test func canCreateWithAtLeastOneValidMessageType() {
        // One empty, one valid — should pass because contains(where:) finds the valid one
        #expect(NewContractSheet.isCreateValid(
            name: "OrderContract",
            messageUsages: [
                (id: UUID(), messageType: "", sentBy: "INITIATOR"),
                (id: UUID(), messageType: "OrderMessage", sentBy: "TARGET")
            ],
            isCreating: false
        ) == true)
    }
}
