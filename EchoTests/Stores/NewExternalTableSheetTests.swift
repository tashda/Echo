import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("NewExternalTableSheet")
struct NewExternalTableSheetTests {

    // MARK: - Validation

    @Test func cannotCreateWithEmptyName() {
        #expect(NewExternalTableSheet.isCreateValid(
            name: "",
            dataSource: "MyDataSource",
            location: "/data/files",
            columns: [(id: UUID(), name: "col1", dataType: "INT")],
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyName() {
        #expect(NewExternalTableSheet.isCreateValid(
            name: "   ",
            dataSource: "MyDataSource",
            location: "/data/files",
            columns: [(id: UUID(), name: "col1", dataType: "INT")],
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWithEmptyDataSource() {
        #expect(NewExternalTableSheet.isCreateValid(
            name: "ExtTable",
            dataSource: "",
            location: "/data/files",
            columns: [(id: UUID(), name: "col1", dataType: "INT")],
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWithEmptyLocation() {
        #expect(NewExternalTableSheet.isCreateValid(
            name: "ExtTable",
            dataSource: "MyDataSource",
            location: "",
            columns: [(id: UUID(), name: "col1", dataType: "INT")],
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWithEmptyColumns() {
        #expect(NewExternalTableSheet.isCreateValid(
            name: "ExtTable",
            dataSource: "MyDataSource",
            location: "/data/files",
            columns: [],
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWithColumnWithEmptyName() {
        #expect(NewExternalTableSheet.isCreateValid(
            name: "ExtTable",
            dataSource: "MyDataSource",
            location: "/data/files",
            columns: [(id: UUID(), name: "", dataType: "INT")],
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWithColumnWithEmptyDataType() {
        #expect(NewExternalTableSheet.isCreateValid(
            name: "ExtTable",
            dataSource: "MyDataSource",
            location: "/data/files",
            columns: [(id: UUID(), name: "col1", dataType: "")],
            isCreating: false
        ) == false)
    }

    @Test func cannotCreateWhileAlreadyCreating() {
        #expect(NewExternalTableSheet.isCreateValid(
            name: "ExtTable",
            dataSource: "MyDataSource",
            location: "/data/files",
            columns: [(id: UUID(), name: "col1", dataType: "INT")],
            isCreating: true
        ) == false)
    }

    @Test func canCreateWithValidInputs() {
        #expect(NewExternalTableSheet.isCreateValid(
            name: "ExtTable",
            dataSource: "MyDataSource",
            location: "/data/files",
            columns: [(id: UUID(), name: "col1", dataType: "INT")],
            isCreating: false
        ) == true)
    }

    @Test func canCreateWithAtLeastOneValidColumn() {
        // One invalid column (empty name) and one valid — should pass
        #expect(NewExternalTableSheet.isCreateValid(
            name: "ExtTable",
            dataSource: "MyDataSource",
            location: "/data/files",
            columns: [
                (id: UUID(), name: "", dataType: "INT"),
                (id: UUID(), name: "col2", dataType: "VARCHAR(100)")
            ],
            isCreating: false
        ) == true)
    }
}
