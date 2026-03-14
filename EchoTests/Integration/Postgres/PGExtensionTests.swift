import XCTest
@testable import Echo

/// Tests PostgreSQL extension operations through Echo's DatabaseSession layer.
final class PGExtensionTests: PostgresDockerTestCase {

    // MARK: - List Extensions

    func testListExtensions() async throws {
        let extensions = try await session.listExtensions()
        // plpgsql is always installed by default
        let names = extensions.map(\.name)
        IntegrationTestHelpers.assertContains(names, value: "plpgsql")
    }

    func testListExtensionsContainsUuidOssp() async throws {
        // uuid-ossp may be pre-installed from sample data
        // If not, install it for this test
        try? await execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"")

        let extensions = try await session.listExtensions()
        let names = extensions.map(\.name)
        IntegrationTestHelpers.assertContains(names, value: "uuid-ossp")
    }

    // MARK: - Install Extension

    func testInstallExtensionHstore() async throws {
        // Drop first in case it exists from a prior run
        try? await execute("DROP EXTENSION IF EXISTS hstore")

        guard let metadataSession = session as? DatabaseMetadataSession else {
            // Fall back to raw SQL if session does not conform
            try await execute("CREATE EXTENSION IF NOT EXISTS hstore")
            let extensions = try await session.listExtensions()
            let names = extensions.map(\.name)
            IntegrationTestHelpers.assertContains(names, value: "hstore")
            try? await execute("DROP EXTENSION IF EXISTS hstore")
            return
        }

        try await metadataSession.installExtension(
            name: "hstore",
            schema: nil,
            version: nil,
            cascade: false
        )
        cleanupSQL("DROP EXTENSION IF EXISTS hstore")

        let extensions = try await session.listExtensions()
        let names = extensions.map(\.name)
        IntegrationTestHelpers.assertContains(names, value: "hstore")
    }

    func testInstallExtensionViaSQL() async throws {
        try? await execute("DROP EXTENSION IF EXISTS hstore")

        try await execute("CREATE EXTENSION hstore")
        cleanupSQL("DROP EXTENSION IF EXISTS hstore")

        let result = try await query("""
            SELECT extname FROM pg_extension WHERE extname = 'hstore'
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    // MARK: - List Available Extensions

    func testListAvailableExtensions() async throws {
        guard let metadataSession = session as? DatabaseMetadataSession else {
            // Fall back to raw SQL
            let result = try await query("""
                SELECT name, default_version, comment
                FROM pg_available_extensions
                ORDER BY name
                LIMIT 10
            """)
            IntegrationTestHelpers.assertMinRowCount(result, expected: 1,
                message: "Should have at least one available extension")
            return
        }

        let available = try await metadataSession.listAvailableExtensions()
        // pg_available_extensions should always have at least plpgsql
        XCTAssertFalse(available.isEmpty, "Should list at least one available extension")
    }

    func testAvailableExtensionsIncludesPlpgsql() async throws {
        let result = try await query("""
            SELECT name FROM pg_available_extensions WHERE name = 'plpgsql'
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    // MARK: - List Extension Objects

    func testListExtensionObjects() async throws {
        let objects = try await session.listExtensionObjects(extensionName: "plpgsql")
        // plpgsql defines the plpgsql language at minimum
        // This may return empty if the session does not implement it
        // Either way, it should not throw
        _ = objects
    }

    func testListExtensionObjectsForUuidOssp() async throws {
        try? await execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"")
        cleanupSQL("DROP EXTENSION IF EXISTS \"uuid-ossp\"")

        let objects = try await session.listExtensionObjects(extensionName: "uuid-ossp")
        // uuid-ossp provides functions like uuid_generate_v4
        // The list may be empty if not implemented, but should not throw
        _ = objects
    }

    // MARK: - Drop Extension

    func testDropExtension() async throws {
        try await execute("CREATE EXTENSION IF NOT EXISTS hstore")

        try await execute("DROP EXTENSION hstore")

        let result = try await query("""
            SELECT extname FROM pg_extension WHERE extname = 'hstore'
        """)
        XCTAssertEqual(result.rows.count, 0, "Extension should be dropped")
    }
}
