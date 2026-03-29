import Foundation
import Testing
@testable import Echo

@MainActor
struct BulkImportViewModelTests {
    @Test
    func buildInsertSQLUsesMySQLIdentifierQuoting() {
        let viewModel = makeViewModel(databaseType: .mysql)

        let sql = viewModel.buildInsertSQL(
            schema: "sakila",
            table: "actor",
            columns: ["first_name", "last_name"],
            rows: [["PENELOPE", "GUINESS"]]
        )

        #expect(sql == "INSERT INTO `sakila`.`actor` (`first_name`, `last_name`) VALUES ('PENELOPE', 'GUINESS')")
    }

    @Test
    func buildInsertSQLUsesPostgresIdentifierQuoting() {
        let viewModel = makeViewModel(databaseType: .postgresql)

        let sql = viewModel.buildInsertSQL(
            schema: "public",
            table: "users",
            columns: ["display_name"],
            rows: [["Ada"]]
        )

        #expect(sql == "INSERT INTO \"public\".\"users\" (\"display_name\") VALUES ('Ada')")
    }

    @Test
    func buildInsertSQLTurnsEmptyValuesIntoNull() {
        let viewModel = makeViewModel(databaseType: .mysql)

        let sql = viewModel.buildInsertSQL(
            schema: nil,
            table: "notes",
            columns: ["title", "body"],
            rows: [["Hello", ""], ["World", "  "]]
        )

        #expect(sql == "INSERT INTO `notes` (`title`, `body`) VALUES ('Hello', NULL), ('World', NULL)")
    }

    private func makeViewModel(databaseType: DatabaseType) -> BulkImportViewModel {
        let session = MockDatabaseSession()
        let connectionSession = ConnectionSession(
            connection: TestFixtures.savedConnection(
                connectionName: "\(databaseType.displayName) Import",
                database: "sample",
                databaseType: databaseType
            ),
            session: session,
            spoolManager: makeSpoolManager()
        )

        return BulkImportViewModel(
            session: session,
            connectionSession: connectionSession,
            databaseType: databaseType,
            schema: "",
            tableName: "sample"
        )
    }

    private func makeSpoolManager() -> ResultSpooler {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("BulkImportViewModelTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let configuration = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: tempRoot)
        return ResultSpooler(configuration: configuration)
    }
}
