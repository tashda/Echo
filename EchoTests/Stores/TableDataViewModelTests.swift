import Foundation
import Testing
@testable import Echo

struct TableDataViewModelTests {
    @Test
    func saveChangesEscapesLiteralValues() async throws {
        let session = MockDatabaseSession()
        let viewModel = makeViewModel(session: session)
        var executedSQL: [String] = []
        session.executeUpdateHandler = { sql in
            executedSQL.append(sql)
            return 1
        }

        viewModel.editCell(row: 0, column: 1, newValue: "O'Hara")
        await viewModel.saveChanges()

        #expect(executedSQL.count == 1)
        #expect(executedSQL.first?.contains("`name` = 'O''Hara'") == true)
    }

    @Test
    func saveChangesUsesRawExpressionWhenRequested() async throws {
        let session = MockDatabaseSession()
        let viewModel = makeViewModel(session: session)
        var executedSQL: [String] = []
        session.executeUpdateHandler = { sql in
            executedSQL.append(sql)
            return 1
        }

        viewModel.editCell(row: 0, column: 1, newValue: "UUID()", valueMode: .expression)
        await viewModel.saveChanges()

        #expect(executedSQL.count == 1)
        #expect(executedSQL.first?.contains("`name` = UUID()") == true)
        #expect(executedSQL.first?.contains("'UUID()'") == false)
    }

    @Test
    func transformCellTextUpdatesVisibleRowAndPendingEdit() {
        let viewModel = makeViewModel()

        viewModel.transformCellText(row: 0, column: 1, using: .uppercase)

        #expect(viewModel.rows[0][1] == "ALICE")
        #expect(viewModel.pendingEdits.count == 1)
        #expect(viewModel.pendingEdits[0].newValue == "ALICE")
    }

    @Test
    func loadCellValueReadsFileIntoCell() throws {
        let viewModel = makeViewModel()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
        try "loaded from file".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        viewModel.loadCellValue(row: 0, column: 1, from: url)

        #expect(viewModel.rows[0][1] == "loaded from file")
        #expect(viewModel.pendingEdits.first?.newValue == "loaded from file")
    }

    @Test
    func setValueModePreservesCurrentCellContents() {
        let viewModel = makeViewModel()

        viewModel.setValueMode(row: 0, column: 1, to: .expression)

        #expect(viewModel.rows[0][1] == "alice")
        #expect(viewModel.pendingEdits.first?.valueMode == .expression)
    }

    private func makeViewModel(session: MockDatabaseSession = MockDatabaseSession()) -> TableDataViewModel {
        let viewModel = TableDataViewModel(
            schemaName: "public",
            tableName: "users",
            databaseType: .mysql,
            session: session
        )
        viewModel.columns = [
            TableDataColumn(name: "id", dataType: "int", isPrimaryKey: true),
            TableDataColumn(name: "name", dataType: "varchar(255)", isPrimaryKey: false)
        ]
        viewModel.primaryKeyColumns = ["id"]
        viewModel.rows = [["1", "alice"]]
        viewModel.totalLoadedRows = 1
        viewModel.isEditMode = true
        return viewModel
    }
}
