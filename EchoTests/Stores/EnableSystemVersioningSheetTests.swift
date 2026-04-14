import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("EnableSystemVersioningSheet")
struct EnableSystemVersioningSheetTests {

    // MARK: - Validation

    @Test func cannotCreateWithEmptyStartColumn() {
        #expect(EnableSystemVersioningSheet.isCreateValid(
            startColumn: "",
            endColumn: "ValidTo",
            historyTableName: "dbo.HistoryTable",
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyStartColumn() {
        #expect(EnableSystemVersioningSheet.isCreateValid(
            startColumn: "   ",
            endColumn: "ValidTo",
            historyTableName: "dbo.HistoryTable",
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWithEmptyEndColumn() {
        #expect(EnableSystemVersioningSheet.isCreateValid(
            startColumn: "ValidFrom",
            endColumn: "",
            historyTableName: "dbo.HistoryTable",
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyEndColumn() {
        #expect(EnableSystemVersioningSheet.isCreateValid(
            startColumn: "ValidFrom",
            endColumn: "   ",
            historyTableName: "dbo.HistoryTable",
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWithEmptyHistoryTableName() {
        #expect(EnableSystemVersioningSheet.isCreateValid(
            startColumn: "ValidFrom",
            endColumn: "ValidTo",
            historyTableName: "",
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyHistoryTableName() {
        #expect(EnableSystemVersioningSheet.isCreateValid(
            startColumn: "ValidFrom",
            endColumn: "ValidTo",
            historyTableName: "   ",
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWhileAlreadyCreating() {
        #expect(EnableSystemVersioningSheet.isCreateValid(
            startColumn: "ValidFrom",
            endColumn: "ValidTo",
            historyTableName: "dbo.HistoryTable",
            isCreating: true
        ) == false)
    }

    @Test func canCreateWithValidInputs() {
        #expect(EnableSystemVersioningSheet.isCreateValid(
            startColumn: "ValidFrom",
            endColumn: "ValidTo",
            historyTableName: "dbo.HistoryTable",
            isCreating: false
        ) == true)
    }
}
