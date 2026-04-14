import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("NewServerTriggerSheet")
struct NewServerTriggerSheetTests {

    // MARK: - Validation

    @Test func cannotCreateWithEmptyName() {
        #expect(NewServerTriggerSheet.isCreateValid(name: "", selectedEvents: ["LOGON"], body: "PRINT 1", isCreating: false) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyName() {
        #expect(NewServerTriggerSheet.isCreateValid(name: "   ", selectedEvents: ["LOGON"], body: "PRINT 1", isCreating: false) == false)
    }

    @Test func cannotCreateWithEmptyEvents() {
        #expect(NewServerTriggerSheet.isCreateValid(name: "trg_test", selectedEvents: [], body: "PRINT 1", isCreating: false) == false)
    }

    @Test func cannotCreateWithEmptyBody() {
        #expect(NewServerTriggerSheet.isCreateValid(name: "trg_test", selectedEvents: ["LOGON"], body: "", isCreating: false) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyBody() {
        #expect(NewServerTriggerSheet.isCreateValid(name: "trg_test", selectedEvents: ["LOGON"], body: "   ", isCreating: false) == false)
    }

    @Test func cannotCreateWhileAlreadyCreating() {
        #expect(NewServerTriggerSheet.isCreateValid(name: "trg_test", selectedEvents: ["LOGON"], body: "PRINT 1", isCreating: true) == false)
    }

    @Test func canCreateWithValidInputs() {
        #expect(NewServerTriggerSheet.isCreateValid(name: "trg_test", selectedEvents: ["LOGON"], body: "PRINT 1", isCreating: false) == true)
    }

    @Test func canCreateWithMultipleEvents() {
        #expect(NewServerTriggerSheet.isCreateValid(name: "trg_test", selectedEvents: ["LOGON", "LOGOFF"], body: "PRINT 1", isCreating: false) == true)
    }
}
