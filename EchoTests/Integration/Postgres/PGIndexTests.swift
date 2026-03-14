import XCTest
@testable import Echo

/// Tests PostgreSQL index operations through Echo's DatabaseSession layer.
final class PGIndexTests: PostgresDockerTestCase {

    // MARK: - B-tree Index

    func testCreateBTreeIndex() async throws {
        let tableName = uniqueName()
        let indexName = "ix_\(tableName)_name"
        try await execute("CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, name TEXT, email TEXT)")
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        try await execute("CREATE INDEX \(indexName) ON public.\(tableName)(name)")

        let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
        let hasIndex = details.indexes.contains { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }
        XCTAssertTrue(hasIndex, "Should detect the created B-tree index")
    }

    // MARK: - Unique Index

    func testCreateUniqueIndex() async throws {
        let tableName = uniqueName()
        let indexName = "ux_\(tableName)_email"
        try await execute("CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, email TEXT)")
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        try await execute("CREATE UNIQUE INDEX \(indexName) ON public.\(tableName)(email)")

        let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
        let uniqueIdx = details.indexes.first { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }
        XCTAssertNotNil(uniqueIdx)
        XCTAssertTrue(uniqueIdx?.isUnique ?? false)
    }

    // MARK: - Composite Index

    func testCreateCompositeIndex() async throws {
        let tableName = uniqueName()
        let indexName = "ix_\(tableName)_composite"
        try await execute("CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, last_name TEXT, first_name TEXT)")
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        try await execute("CREATE INDEX \(indexName) ON public.\(tableName)(last_name, first_name)")

        let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
        let idx = details.indexes.first { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }
        XCTAssertNotNil(idx)
        XCTAssertGreaterThanOrEqual(idx?.columns.count ?? 0, 2)
    }

    // MARK: - GIN Index

    func testCreateGINIndex() async throws {
        let tableName = uniqueName()
        let indexName = "ix_\(tableName)_data_gin"
        try await execute("CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, data JSONB)")
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        try await execute("CREATE INDEX \(indexName) ON public.\(tableName) USING GIN (data)")

        // Verify the index exists via pg_indexes
        let result = try await query("""
            SELECT indexname FROM pg_indexes
            WHERE schemaname = 'public' AND tablename = '\(tableName)' AND indexname = '\(indexName)'
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    // MARK: - Partial / Filtered Index

    func testCreatePartialIndex() async throws {
        let tableName = uniqueName()
        let indexName = "ix_\(tableName)_active"
        try await execute("CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, status TEXT, name TEXT)")
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        try await execute("CREATE INDEX \(indexName) ON public.\(tableName)(name) WHERE status = 'active'")

        let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
        let idx = details.indexes.first { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }
        XCTAssertNotNil(idx)
    }

    // MARK: - Rebuild Index

    func testRebuildIndex() async throws {
        let tableName = uniqueName()
        let indexName = "ix_\(tableName)_rebuild"
        try await execute("CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, name TEXT)")
        try await execute("CREATE INDEX \(indexName) ON public.\(tableName)(name)")
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        // Insert some data
        for i in 1...50 {
            try await execute("INSERT INTO public.\(tableName) (name) VALUES ('name_\(i)')")
        }

        // REINDEX should not throw
        try await session.rebuildIndex(schema: "public", table: tableName, index: indexName)

        // Verify table still works after rebuild
        let result = try await query("SELECT COUNT(*) AS cnt FROM public.\(tableName)")
        XCTAssertEqual(result.rows[0][0], "50")
    }

    // MARK: - Drop Index

    func testDropIndex() async throws {
        let tableName = uniqueName()
        let indexName = "ix_\(tableName)_drop"
        try await execute("CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, name TEXT)")
        try await execute("CREATE INDEX \(indexName) ON public.\(tableName)(name)")
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        try await execute("DROP INDEX \(indexName)")

        let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
        let hasIndex = details.indexes.contains { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }
        XCTAssertFalse(hasIndex, "Index should be dropped")
    }
}
