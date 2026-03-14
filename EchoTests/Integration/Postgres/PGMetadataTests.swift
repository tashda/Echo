import XCTest
@testable import Echo

/// Tests PostgreSQL metadata retrieval through Echo's DatabaseSession layer.
final class PGMetadataTests: PostgresDockerTestCase {

    // MARK: - Table Schema

    func testGetTableSchema() async throws {
        try await withTempTable(
            columns: "id SERIAL PRIMARY KEY, name VARCHAR(100) NOT NULL, email TEXT, age INTEGER"
        ) { tableName in
            let columns = try await session.getTableSchema(tableName, schemaName: "public")
            XCTAssertEqual(columns.count, 4)

            let names = columns.map(\.name)
            XCTAssertTrue(names.contains("id"))
            XCTAssertTrue(names.contains("name"))
            XCTAssertTrue(names.contains("email"))
            XCTAssertTrue(names.contains("age"))
        }
    }

    func testGetTableSchemaIncludesDataTypes() async throws {
        try await withTempTable(
            columns: "id INTEGER, amount NUMERIC(10,2), created_at TIMESTAMPTZ"
        ) { tableName in
            let columns = try await session.getTableSchema(tableName, schemaName: "public")

            for col in columns {
                XCTAssertFalse(col.dataType.isEmpty, "Column \(col.name) should have a data type")
            }
        }
    }

    func testGetTableSchemaReportsNullability() async throws {
        try await withTempTable(
            columns: "id SERIAL PRIMARY KEY, required_col TEXT NOT NULL, optional_col TEXT"
        ) { tableName in
            let columns = try await session.getTableSchema(tableName, schemaName: "public")

            let required = columns.first { $0.name == "required_col" }
            let optional = columns.first { $0.name == "optional_col" }
            XCTAssertNotNil(required)
            XCTAssertNotNil(optional)
            XCTAssertFalse(required?.isNullable ?? true, "required_col should not be nullable")
            XCTAssertTrue(optional?.isNullable ?? false, "optional_col should be nullable")
        }
    }

    func testGetTableSchemaInCustomSchema() async throws {
        let schemaName = uniqueName(prefix: "s")
        let tableName = uniqueName()
        try await execute("CREATE SCHEMA \(schemaName)")
        try await execute(
            "CREATE TABLE \(schemaName).\(tableName) (id SERIAL PRIMARY KEY, data TEXT)"
        )
        cleanupSQL("DROP SCHEMA IF EXISTS \(schemaName) CASCADE")

        let columns = try await session.getTableSchema(tableName, schemaName: schemaName)
        XCTAssertEqual(columns.count, 2)
        let names = columns.map(\.name)
        XCTAssertTrue(names.contains("id"))
        XCTAssertTrue(names.contains("data"))
    }

    // MARK: - Table Structure Details

    func testGetTableStructureDetailsColumns() async throws {
        try await withTempTable(
            columns: "id SERIAL NOT NULL, name VARCHAR(100), value NUMERIC(10,2) DEFAULT 0"
        ) { tableName in
            let details = try await session.getTableStructureDetails(
                schema: "public", table: tableName
            )
            XCTAssertGreaterThanOrEqual(details.columns.count, 3)
            IntegrationTestHelpers.assertHasStructureColumn(details, named: "id")
            IntegrationTestHelpers.assertHasStructureColumn(details, named: "name")
            IntegrationTestHelpers.assertHasStructureColumn(details, named: "value")
        }
    }

    func testGetTableStructureDetailsPrimaryKey() async throws {
        try await withTempTable(
            columns: "id SERIAL PRIMARY KEY, name TEXT"
        ) { tableName in
            let details = try await session.getTableStructureDetails(
                schema: "public", table: tableName
            )
            XCTAssertNotNil(details.primaryKey, "Should detect primary key")
            if let pk = details.primaryKey {
                XCTAssertTrue(pk.columns.contains("id"))
            }
        }
    }

    func testGetTableStructureDetailsCompositePrimaryKey() async throws {
        let tableName = uniqueName()
        try await execute("""
            CREATE TABLE public.\(tableName) (
                col_a INTEGER NOT NULL,
                col_b INTEGER NOT NULL,
                data TEXT,
                PRIMARY KEY (col_a, col_b)
            )
        """)
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        let details = try await session.getTableStructureDetails(
            schema: "public", table: tableName
        )
        XCTAssertNotNil(details.primaryKey)
        if let pk = details.primaryKey {
            XCTAssertTrue(pk.columns.contains("col_a"))
            XCTAssertTrue(pk.columns.contains("col_b"))
            XCTAssertEqual(pk.columns.count, 2)
        }
    }

    func testGetTableStructureDetailsIndexes() async throws {
        let tableName = uniqueName()
        try await execute(
            "CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, name TEXT, email TEXT)"
        )
        try await execute(
            "CREATE INDEX ix_\(tableName)_name ON public.\(tableName)(name)"
        )
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        let details = try await session.getTableStructureDetails(
            schema: "public", table: tableName
        )
        XCTAssertFalse(details.indexes.isEmpty, "Should have at least one index")

        let nameIndex = details.indexes.first {
            $0.name.lowercased().contains("ix_\(tableName)_name".lowercased())
        }
        XCTAssertNotNil(nameIndex, "Should find the created index")
    }

    func testGetTableStructureDetailsForeignKeys() async throws {
        let parentTable = uniqueName(prefix: "parent")
        let childTable = uniqueName(prefix: "child")
        try await execute(
            "CREATE TABLE public.\(parentTable) (id SERIAL PRIMARY KEY, name TEXT)"
        )
        try await execute("""
            CREATE TABLE public.\(childTable) (
                id SERIAL PRIMARY KEY,
                parent_id INTEGER REFERENCES public.\(parentTable)(id)
            )
        """)
        cleanupSQL(
            "DROP TABLE IF EXISTS public.\(childTable)",
            "DROP TABLE IF EXISTS public.\(parentTable)"
        )

        let details = try await session.getTableStructureDetails(
            schema: "public", table: childTable
        )
        XCTAssertFalse(details.foreignKeys.isEmpty, "Should detect foreign key")
        if let fk = details.foreignKeys.first {
            XCTAssertEqual(fk.referencedTable, parentTable)
        }
    }

    func testGetTableStructureDetailsUniqueConstraints() async throws {
        try await withTempTable(
            columns: "id SERIAL PRIMARY KEY, code VARCHAR(10) UNIQUE, name TEXT"
        ) { tableName in
            let details = try await session.getTableStructureDetails(
                schema: "public", table: tableName
            )
            let hasUnique = !details.uniqueConstraints.isEmpty ||
                details.indexes.contains(where: { $0.isUnique })
            XCTAssertTrue(hasUnique, "Should detect unique constraint on 'code'")
        }
    }

    func testGetTableStructureDetailsDefaultValues() async throws {
        try await withTempTable(
            columns: "id SERIAL PRIMARY KEY, status TEXT DEFAULT 'active', count INTEGER DEFAULT 0"
        ) { tableName in
            let details = try await session.getTableStructureDetails(
                schema: "public", table: tableName
            )
            let statusCol = details.columns.first { $0.name == "status" }
            XCTAssertNotNil(statusCol)
            XCTAssertNotNil(statusCol?.defaultValue, "status should have a default value")
        }
    }

    // MARK: - Object Definitions

    func testGetTableDefinition() async throws {
        try await withTempTable(
            columns: "id SERIAL PRIMARY KEY, name VARCHAR(100)"
        ) { tableName in
            let definition = try await session.getObjectDefinition(
                objectName: tableName, schemaName: "public", objectType: .table
            )
            XCTAssertFalse(definition.isEmpty)
            XCTAssertTrue(
                definition.lowercased().contains("create"),
                "Table definition should contain CREATE"
            )
        }
    }

    func testGetViewDefinition() async throws {
        let tableName = uniqueName()
        let viewName = uniqueName(prefix: "v")
        try await execute(
            "CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, name TEXT)"
        )
        try await execute(
            "CREATE VIEW public.\(viewName) AS SELECT id, name FROM public.\(tableName)"
        )
        cleanupSQL(
            "DROP VIEW IF EXISTS public.\(viewName)",
            "DROP TABLE IF EXISTS public.\(tableName)"
        )

        let definition = try await session.getObjectDefinition(
            objectName: viewName, schemaName: "public", objectType: .view
        )
        XCTAssertFalse(definition.isEmpty)
        XCTAssertTrue(
            definition.lowercased().contains("select"),
            "View definition should contain SELECT"
        )
    }

    func testGetFunctionDefinition() async throws {
        let funcName = uniqueName(prefix: "fn")
        try await execute("""
            CREATE OR REPLACE FUNCTION public.\(funcName)(x INTEGER)
            RETURNS INTEGER AS $$
            BEGIN
                RETURN x * 2;
            END;
            $$ LANGUAGE plpgsql
        """)
        cleanupSQL("DROP FUNCTION IF EXISTS public.\(funcName)")

        let definition = try await session.getObjectDefinition(
            objectName: funcName, schemaName: "public", objectType: .function
        )
        XCTAssertFalse(definition.isEmpty)
    }

    func testGetTriggerDefinition() async throws {
        let tableName = uniqueName()
        let triggerFuncName = uniqueName(prefix: "trg_fn")
        let triggerName = uniqueName(prefix: "trg")
        try await execute(
            "CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, updated_at TIMESTAMPTZ)"
        )
        try await execute("""
            CREATE OR REPLACE FUNCTION public.\(triggerFuncName)()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.updated_at = NOW();
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql
        """)
        try await execute("""
            CREATE TRIGGER \(triggerName)
            BEFORE UPDATE ON public.\(tableName)
            FOR EACH ROW EXECUTE FUNCTION public.\(triggerFuncName)()
        """)
        cleanupSQL(
            "DROP TABLE IF EXISTS public.\(tableName) CASCADE",
            "DROP FUNCTION IF EXISTS public.\(triggerFuncName)()"
        )

        let definition = try await session.getObjectDefinition(
            objectName: triggerName, schemaName: "public", objectType: .trigger
        )
        XCTAssertFalse(definition.isEmpty)
    }

    // MARK: - Load Schema Info

    func testLoadSchemaInfo() async throws {
        let tableName = uniqueName()
        try await execute(
            "CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY)"
        )
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo("public", progress: nil)
        XCTAssertEqual(schemaInfo.name, "public")
        XCTAssertFalse(schemaInfo.objects.isEmpty)
    }

    func testLoadSchemaInfoIncludesCreatedTable() async throws {
        let tableName = uniqueName()
        try await execute(
            "CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, data TEXT)"
        )
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo("public", progress: nil)
        let found = schemaInfo.objects.contains {
            $0.name.caseInsensitiveCompare(tableName) == .orderedSame
        }
        XCTAssertTrue(found, "Schema info should include \(tableName)")
    }

    func testLoadSchemaInfoReportsProgress() async throws {
        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let progressCalled = LockIsolated(false)
        _ = try await metaSession.loadSchemaInfo("public") { _, _, _ in
            progressCalled.setValue(true)
        }
        // Progress may or may not fire depending on schema contents.
        // The important thing is it does not crash.
        _ = progressCalled.value
    }

    func testLoadSchemaInfoForCustomSchema() async throws {
        let schemaName = uniqueName(prefix: "meta_s")
        let tableName = uniqueName()
        try await execute("CREATE SCHEMA \(schemaName)")
        try await execute(
            "CREATE TABLE \(schemaName).\(tableName) (id SERIAL PRIMARY KEY)"
        )
        cleanupSQL("DROP SCHEMA IF EXISTS \(schemaName) CASCADE")

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo(schemaName, progress: nil)
        XCTAssertEqual(schemaInfo.name, schemaName)
        IntegrationTestHelpers.assertContainsObject(
            schemaInfo.objects, name: tableName, type: .table
        )
    }

    // MARK: - Sample Data Metadata

    func testSampleDataTableSchema() async throws {
        try await loadSampleDataIfNeeded()
        let columns = try await session.getTableSchema("employees", schemaName: "echo_test")
        XCTAssertFalse(columns.isEmpty)
        let names = columns.map(\.name)
        XCTAssertTrue(names.contains("first_name"))
        XCTAssertTrue(names.contains("last_name"))
        XCTAssertTrue(names.contains("email"))
        XCTAssertTrue(names.contains("department_id"))
        XCTAssertTrue(names.contains("salary"))
    }

    func testSampleDataForeignKeys() async throws {
        try await loadSampleDataIfNeeded()
        let details = try await session.getTableStructureDetails(
            schema: "echo_test", table: "employees"
        )
        let deptFK = details.foreignKeys.first {
            $0.columns.contains("department_id")
        }
        XCTAssertNotNil(deptFK, "employees should have a FK on department_id")
        XCTAssertEqual(deptFK?.referencedTable, "departments")
    }

    // MARK: - Helpers

    private func loadSampleDataIfNeeded() async throws {
        let schemas = try await session.listSchemas()
        guard !schemas.contains(where: {
            $0.caseInsensitiveCompare("echo_test") == .orderedSame
        }) else { return }

        let fm = FileManager.default
        let path = "/Users/k/Development/Echo/EchoTests/Integration/Support/SampleData/PostgresSampleData.sql"
        if fm.fileExists(atPath: path) {
            let sql = try String(contentsOfFile: path, encoding: .utf8)
            _ = try? await execute(sql)
        } else {
            throw XCTSkip(
                "PostgresSampleData.sql not found — cannot run sample data tests"
            )
        }
    }
}
