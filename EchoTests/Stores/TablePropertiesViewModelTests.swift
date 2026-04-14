import Foundation
import Testing
@testable import Echo

@MainActor
struct TablePropertiesViewModelTests {
    private func makeSpoolManager() -> ResultSpooler {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("TablePropertiesViewModelTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let configuration = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: tempRoot)
        return ResultSpooler(configuration: configuration)
    }

    private func makeConnectionSession(session: MockDatabaseSession) -> ConnectionSession {
        ConnectionSession(
            connection: TestFixtures.savedConnection(
                connectionName: "MySQL Test",
                database: "sakila",
                databaseType: .mysql
            ),
            session: session,
            spoolManager: makeSpoolManager()
        )
    }

    @Test
    func loadPropertiesMapsMySQLTableOptionsIntoSharedState() async {
        let session = MockDatabaseSession()
        session.getTableStructureDetailsHandler = { _, _ in
            TableStructureDetails(
                columns: [],
                primaryKey: nil,
                indexes: [],
                uniqueConstraints: [],
                foreignKeys: [],
                dependencies: [],
                tableProperties: TableStructureDetails.TableProperties(
                    storageEngine: "InnoDB",
                    characterSet: "utf8mb4",
                    collation: "utf8mb4_0900_ai_ci",
                    autoIncrementValue: 512,
                    rowFormat: "Dynamic",
                    tableComment: "actors",
                    estimatedRowCount: 200,
                    dataLengthBytes: 16_384,
                    indexLengthBytes: 8_192
                )
            )
        }

        let connectionSession = makeConnectionSession(session: session)
        let viewModel = TablePropertiesViewModel(
            connectionSessionID: connectionSession.id,
            schemaName: "sakila",
            tableName: "actor",
            databaseType: .mysql
        )

        await viewModel.loadProperties(session: connectionSession)

        #expect(viewModel.mysqlEngine == "InnoDB")
        #expect(viewModel.mysqlCharacterSet == "utf8mb4")
        #expect(viewModel.mysqlCollation == "utf8mb4_0900_ai_ci")
        #expect(viewModel.mysqlAutoIncrement == "512")
        #expect(viewModel.mysqlRowFormat == "Dynamic")
        #expect(viewModel.mysqlComment == "actors")
        #expect(viewModel.rowCount == 200)
        #expect(viewModel.tableSizeBytes == 16_384)
        #expect(viewModel.indexesSizeBytes == 8_192)
        #expect(viewModel.totalSizeBytes == 24_576)
    }

    @Test
    func submitChangesGeneratesMySQLAlterStatements() async throws {
        let session = MockDatabaseSession()
        session.getTableStructureDetailsHandler = { _, _ in
            TableStructureDetails(
                tableProperties: TableStructureDetails.TableProperties(
                    storageEngine: "InnoDB",
                    characterSet: "utf8mb4",
                    collation: "utf8mb4_0900_ai_ci",
                    autoIncrementValue: 512,
                    rowFormat: "Dynamic",
                    tableComment: "actors"
                )
            )
        }
        var executedSQL: [String] = []
        session.executeUpdateHandler = { sql in
            executedSQL.append(sql)
            return 0
        }

        let connectionSession = makeConnectionSession(session: session)
        let viewModel = TablePropertiesViewModel(
            connectionSessionID: connectionSession.id,
            schemaName: "sakila",
            tableName: "actor",
            databaseType: .mysql
        )
        await viewModel.loadProperties(session: connectionSession)

        viewModel.mysqlEngine = "MyISAM"
        viewModel.mysqlCharacterSet = "latin1"
        viewModel.mysqlCollation = "latin1_swedish_ci"
        viewModel.mysqlAutoIncrement = "1000"
        viewModel.mysqlRowFormat = "Fixed"
        viewModel.mysqlComment = "archive table"

        try await viewModel.submitChanges(session: connectionSession)

        #expect(executedSQL.count == 3)
        #expect(executedSQL[0] == "ALTER TABLE `sakila`.`actor` ENGINE = MyISAM, AUTO_INCREMENT = 1000, ROW_FORMAT = Fixed, COMMENT = 'archive table';")
        #expect(executedSQL[1] == "ALTER TABLE `sakila`.`actor` CONVERT TO CHARACTER SET latin1;")
        #expect(executedSQL[2] == "ALTER TABLE `sakila`.`actor` COLLATE = latin1_swedish_ci;")
    }
}
