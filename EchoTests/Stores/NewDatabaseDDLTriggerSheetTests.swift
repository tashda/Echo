import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("NewDatabaseDDLTriggerSheet")
struct NewDatabaseDDLTriggerSheetTests {

    // MARK: - Validation

    @Test func cannotCreateWithEmptyName() {
        #expect(NewDatabaseDDLTriggerSheet.isCreateValid(name: "", selectedEvents: ["CREATE_TABLE"], body: "PRINT 1", isCreating: false) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyName() {
        #expect(NewDatabaseDDLTriggerSheet.isCreateValid(name: "   ", selectedEvents: ["CREATE_TABLE"], body: "PRINT 1", isCreating: false) == false)
    }

    @Test func cannotCreateWithEmptyEvents() {
        #expect(NewDatabaseDDLTriggerSheet.isCreateValid(name: "trg_ddl", selectedEvents: [], body: "PRINT 1", isCreating: false) == false)
    }

    @Test func cannotCreateWithEmptyBody() {
        #expect(NewDatabaseDDLTriggerSheet.isCreateValid(name: "trg_ddl", selectedEvents: ["CREATE_TABLE"], body: "", isCreating: false) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyBody() {
        #expect(NewDatabaseDDLTriggerSheet.isCreateValid(name: "trg_ddl", selectedEvents: ["CREATE_TABLE"], body: "   ", isCreating: false) == false)
    }

    @Test func cannotCreateWhileAlreadyCreating() {
        #expect(NewDatabaseDDLTriggerSheet.isCreateValid(name: "trg_ddl", selectedEvents: ["CREATE_TABLE"], body: "PRINT 1", isCreating: true) == false)
    }

    @Test func canCreateWithValidInputs() {
        #expect(NewDatabaseDDLTriggerSheet.isCreateValid(name: "trg_ddl", selectedEvents: ["CREATE_TABLE"], body: "PRINT 1", isCreating: false) == true)
    }

    @Test func canCreateWithMultipleEvents() {
        #expect(NewDatabaseDDLTriggerSheet.isCreateValid(name: "trg_ddl", selectedEvents: ["CREATE_TABLE", "ALTER_TABLE"], body: "PRINT 1", isCreating: false) == true)
    }
}
