import XCTest
@testable import Echo

/// Tests SQLite trigger discovery, PRAGMA browsing, and attach/detach.
final class SQLiteTriggerDiscoveryTests: XCTestCase {

    private var session: SQLiteSession!

    override func setUp() async throws {
        try await super.setUp()
        let factory = SQLiteFactory()
        let rawSession = try await factory.connect(
            host: ":memory:",
            port: 0,
            database: nil,
            tls: false,
            authentication: DatabaseAuthenticationConfiguration(
                method: .sqlPassword,
                username: "",
                password: ""
            ),
            connectTimeoutSeconds: 5
        )
        session = rawSession as? SQLiteSession
        XCTAssertNotNil(session, "Expected SQLiteSession")
    }

    override func tearDown() async throws {
        if let session { await session.close() }
        session = nil
        try await super.tearDown()
    }

    // MARK: - Trigger Discovery (S6)

    func testListTriggersEmpty() async throws {
        _ = try await session.executeUpdate("CREATE TABLE t1 (id INTEGER PRIMARY KEY)")
        let triggers = try await session.listTriggers(schema: nil)
        XCTAssertTrue(triggers.isEmpty, "No triggers should exist yet")
    }

    func testListTriggersFindsAfterInsertTrigger() async throws {
        _ = try await session.executeUpdate("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
        _ = try await session.executeUpdate("CREATE TABLE audit (action TEXT)")
        _ = try await session.executeUpdate("""
            CREATE TRIGGER log_insert AFTER INSERT ON users
            BEGIN
                INSERT INTO audit(action) VALUES('insert');
            END
        """)

        let triggers = try await session.listTriggers(schema: nil)
        XCTAssertEqual(triggers.count, 1)

        let trigger = triggers[0]
        XCTAssertEqual(trigger.name, "log_insert")
        XCTAssertEqual(trigger.type, .trigger)
        XCTAssertEqual(trigger.triggerAction, "AFTER INSERT")
        XCTAssertEqual(trigger.triggerTable, "users")
    }

    func testListTriggersMultiple() async throws {
        _ = try await session.executeUpdate("CREATE TABLE t1 (id INTEGER PRIMARY KEY)")
        _ = try await session.executeUpdate("""
            CREATE TRIGGER trig1 AFTER INSERT ON t1 BEGIN SELECT 1; END
        """)
        _ = try await session.executeUpdate("""
            CREATE TRIGGER trig2 BEFORE DELETE ON t1 BEGIN SELECT 1; END
        """)

        let triggers = try await session.listTriggers(schema: nil)
        XCTAssertEqual(triggers.count, 2)

        let names = Set(triggers.map(\.name))
        XCTAssertTrue(names.contains("trig1"))
        XCTAssertTrue(names.contains("trig2"))
    }

    func testLoadSchemaInfoIncludesTriggers() async throws {
        _ = try await session.executeUpdate("CREATE TABLE t1 (id INTEGER PRIMARY KEY, name TEXT)")
        _ = try await session.executeUpdate("""
            CREATE TRIGGER t1_trigger AFTER INSERT ON t1 BEGIN SELECT 1; END
        """)

        let schemaInfo = try await session.loadSchemaInfo("main", progress: nil)
        let triggerObjects = schemaInfo.objects.filter { $0.type == .trigger }
        XCTAssertEqual(triggerObjects.count, 1)
        XCTAssertEqual(triggerObjects[0].name, "t1_trigger")

        let tableObjects = schemaInfo.objects.filter { $0.type == .table }
        XCTAssertEqual(tableObjects.count, 1)
        XCTAssertEqual(tableObjects[0].name, "t1")
    }

    func testLoadSchemaInfoEnrichesColumnsWithForeignKeys() async throws {
        _ = try await session.executeUpdate("CREATE TABLE parent (id INTEGER PRIMARY KEY)")
        _ = try await session.executeUpdate("""
            CREATE TABLE child (
                id INTEGER PRIMARY KEY,
                parent_id INTEGER REFERENCES parent(id)
            )
        """)

        let schemaInfo = try await session.loadSchemaInfo("main", progress: nil)
        let child = schemaInfo.objects.first { $0.name == "child" }
        XCTAssertNotNil(child)

        let fkColumn = child?.columns.first { $0.name == "parent_id" }
        XCTAssertNotNil(fkColumn?.foreignKey, "Column should have FK reference")
        XCTAssertEqual(fkColumn?.foreignKey?.referencedTable, "parent")
        XCTAssertEqual(fkColumn?.foreignKey?.referencedColumn, "id")
    }

    func testGetObjectDefinitionForTrigger() async throws {
        _ = try await session.executeUpdate("CREATE TABLE t1 (id INTEGER PRIMARY KEY)")
        _ = try await session.executeUpdate("""
            CREATE TRIGGER my_trig AFTER INSERT ON t1 BEGIN SELECT 1; END
        """)

        let definition = try await session.getObjectDefinition(
            objectName: "my_trig",
            schemaName: "main",
            objectType: .trigger
        )
        XCTAssertTrue(definition.contains("my_trig"))
        XCTAssertTrue(definition.contains("AFTER INSERT"))
    }

    // MARK: - PRAGMA Browser (S7)

    func testFetchPragmaValueReturnsPageSize() async throws {
        let value = try await session.fetchPragmaValue("page_size", schema: nil)
        XCTAssertNotNil(value)
        // Default SQLite page size is typically 4096
        let size = Int(value ?? "0")
        XCTAssertNotNil(size)
        XCTAssertGreaterThan(size ?? 0, 0)
    }

    func testFetchPragmaValueReturnsJournalMode() async throws {
        let value = try await session.fetchPragmaValue("journal_mode", schema: nil)
        XCTAssertNotNil(value)
        // In-memory databases use "memory" journal mode
        XCTAssertEqual(value, "memory")
    }

    func testFetchPragmaValueReturnsForeignKeysStatus() async throws {
        let value = try await session.fetchPragmaValue("foreign_keys", schema: nil)
        XCTAssertNotNil(value)
        // Should be "0" or "1"
        XCTAssertTrue(value == "0" || value == "1")
    }

    func testFetchPragmaValueReturnsEncoding() async throws {
        let value = try await session.fetchPragmaValue("encoding", schema: nil)
        XCTAssertNotNil(value)
        XCTAssertTrue(value?.contains("UTF") == true)
    }

    func testFetchPragmaValueReturnsNilForUnknown() async throws {
        let value = try await session.fetchPragmaValue("nonexistent_pragma", schema: nil)
        XCTAssertNil(value)
    }

    // MARK: - Attach/Detach (S8)

    func testAttachAndDetachDatabase() async throws {
        // Create a temporary database file to attach
        let tempDir = FileManager.default.temporaryDirectory
        let tempDB = tempDir.appendingPathComponent("test_attach_\(UUID().uuidString).sqlite")

        // Create the temp database by connecting and creating a table
        let tempFactory = SQLiteFactory()
        let tempSession = try await tempFactory.connect(
            host: tempDB.path,
            port: 0,
            database: nil,
            tls: false,
            authentication: DatabaseAuthenticationConfiguration(
                method: .sqlPassword,
                username: "",
                password: ""
            ),
            connectTimeoutSeconds: 5
        )
        _ = try await tempSession.executeUpdate("CREATE TABLE attached_table (id INTEGER PRIMARY KEY)")
        await tempSession.close()

        // Attach the database
        try await session.attachSQLiteDatabase(path: tempDB.path, alias: "secondary")

        // Verify the attached database appears in database list
        let databases = try await session.listDatabases()
        XCTAssertTrue(databases.contains("secondary"), "Attached database should appear in list")

        // Verify we can query from the attached database
        let objects = try await session.listTablesAndViews(schema: "secondary")
        let tableNames = objects.map(\.name)
        XCTAssertTrue(tableNames.contains("attached_table"), "Should see tables in attached database")

        // Detach
        try await session.detachSQLiteDatabase(alias: "secondary")

        // Verify it's gone
        let afterDetach = try await session.listDatabases()
        XCTAssertFalse(afterDetach.contains("secondary"), "Detached database should not appear")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDB)
    }

    func testDetachMainDatabaseFails() async throws {
        do {
            try await session.detachSQLiteDatabase(alias: "main")
            XCTFail("Detaching main should fail")
        } catch {
            // Expected — SQLite does not allow detaching "main"
        }
    }

    // MARK: - Validation Helpers

    func testSQLiteAttachSheetValidation() {
        XCTAssertTrue(SQLiteAttachDatabaseSheet.isAttachValid(filePath: "/path/to/db.sqlite", alias: "secondary", isAttaching: false))
        XCTAssertFalse(SQLiteAttachDatabaseSheet.isAttachValid(filePath: "", alias: "secondary", isAttaching: false))
        XCTAssertFalse(SQLiteAttachDatabaseSheet.isAttachValid(filePath: "/path", alias: "", isAttaching: false))
        XCTAssertFalse(SQLiteAttachDatabaseSheet.isAttachValid(filePath: "/path", alias: "main", isAttaching: false))
        XCTAssertFalse(SQLiteAttachDatabaseSheet.isAttachValid(filePath: "/path", alias: "secondary", isAttaching: true))
    }

    func testSQLiteDetachSheetValidation() {
        XCTAssertTrue(SQLiteDetachDatabaseSheet.canDetachDatabase("secondary"))
        XCTAssertFalse(SQLiteDetachDatabaseSheet.canDetachDatabase("main"))
        XCTAssertFalse(SQLiteDetachDatabaseSheet.canDetachDatabase("temp"))
        XCTAssertFalse(SQLiteDetachDatabaseSheet.canDetachDatabase("MAIN"))
    }

    func testAliasFromFilePath() {
        let url = URL(fileURLWithPath: "/path/to/my_database.sqlite")
        XCTAssertEqual(SQLiteAttachDatabaseSheet.aliasFromFilePath(url), "my_database")
    }
}
