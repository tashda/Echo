import XCTest
import PostgresKit
@testable import Echo

/// Tests that sequences, types, and procedures appear correctly in schema info
/// loaded through Echo's `DatabaseMetadataSession` layer.
final class PGNewObjectTypesTests: PostgresDockerTestCase {

    // MARK: - Sequences in Schema Info

    func testSequenceAppearsInSchemaInfo() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await postgresClient.admin.createSequence(name: seqName)
        cleanupSQL("DROP SEQUENCE IF EXISTS public.\(seqName)")

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo("public", progress: nil)
        IntegrationTestHelpers.assertContainsObject(
            schemaInfo.objects, name: seqName, type: .sequence
        )
    }

    func testSequenceInCustomSchemaAppearsInSchemaInfo() async throws {
        let schemaName = uniqueName(prefix: "sch")
        let seqName = uniqueName(prefix: "seq")
        try await postgresClient.admin.createSchema(name: schemaName)
        try await postgresClient.admin.createSequence(
            name: "\(schemaName).\(seqName)", startWith: 1
        )
        cleanupSQL("DROP SCHEMA IF EXISTS \(schemaName) CASCADE")

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo(schemaName, progress: nil)
        IntegrationTestHelpers.assertContainsObject(
            schemaInfo.objects, name: seqName, type: .sequence
        )
    }

    func testSequenceDoesNotAppearAsFunctionOrTable() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await postgresClient.admin.createSequence(name: seqName)
        cleanupSQL("DROP SEQUENCE IF EXISTS public.\(seqName)")

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo("public", progress: nil)
        let tables = schemaInfo.tables
        let functions = schemaInfo.functions

        XCTAssertFalse(
            tables.contains { $0.name.caseInsensitiveCompare(seqName) == .orderedSame },
            "Sequence '\(seqName)' should not appear as a table"
        )
        XCTAssertFalse(
            functions.contains { $0.name.caseInsensitiveCompare(seqName) == .orderedSame },
            "Sequence '\(seqName)' should not appear as a function"
        )
    }

    // MARK: - Enum Types in Schema Info

    func testEnumTypeAppearsInSchemaInfo() async throws {
        let typeName = uniqueName(prefix: "enum")
        try await execute("CREATE TYPE public.\(typeName) AS ENUM ('a', 'b', 'c')")
        cleanupSQL("DROP TYPE IF EXISTS public.\(typeName)")

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo("public", progress: nil)
        IntegrationTestHelpers.assertContainsObject(
            schemaInfo.objects, name: typeName, type: .type
        )
    }

    func testEnumTypeDoesNotAppearAsTable() async throws {
        let typeName = uniqueName(prefix: "enum")
        try await execute("CREATE TYPE public.\(typeName) AS ENUM ('x', 'y')")
        cleanupSQL("DROP TYPE IF EXISTS public.\(typeName)")

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo("public", progress: nil)
        let tables = schemaInfo.tables
        XCTAssertFalse(
            tables.contains { $0.name.caseInsensitiveCompare(typeName) == .orderedSame },
            "Enum type '\(typeName)' should not appear as a table"
        )
    }

    // MARK: - Composite Types in Schema Info

    func testCompositeTypeAppearsInSchemaInfo() async throws {
        let typeName = uniqueName(prefix: "comp")
        try await execute("CREATE TYPE public.\(typeName) AS (x INT, y INT)")
        cleanupSQL("DROP TYPE IF EXISTS public.\(typeName)")

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo("public", progress: nil)
        IntegrationTestHelpers.assertContainsObject(
            schemaInfo.objects, name: typeName, type: .type
        )
    }

    func testCompositeTypeDoesNotAppearAsTable() async throws {
        let typeName = uniqueName(prefix: "comp")
        try await execute("CREATE TYPE public.\(typeName) AS (a TEXT, b INT)")
        cleanupSQL("DROP TYPE IF EXISTS public.\(typeName)")

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo("public", progress: nil)
        let tables = schemaInfo.tables
        XCTAssertFalse(
            tables.contains { $0.name.caseInsensitiveCompare(typeName) == .orderedSame },
            "Composite type '\(typeName)' should not appear as a table"
        )
    }

    // MARK: - Domain Types in Schema Info

    func testDomainTypeAppearsInSchemaInfo() async throws {
        let typeName = uniqueName(prefix: "dom")
        try await execute(
            "CREATE DOMAIN public.\(typeName) AS TEXT CHECK (VALUE <> '')"
        )
        cleanupSQL("DROP DOMAIN IF EXISTS public.\(typeName)")

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo("public", progress: nil)
        IntegrationTestHelpers.assertContainsObject(
            schemaInfo.objects, name: typeName, type: .type
        )
    }

    // MARK: - Procedures in Schema Info

    func testProcedureAppearsAsProcedureNotFunction() async throws {
        let procName = uniqueName(prefix: "proc")
        try await execute("""
            CREATE PROCEDURE public.\(procName)()
            LANGUAGE SQL AS $$ SELECT 1; $$
        """)
        cleanupSQL("DROP PROCEDURE IF EXISTS public.\(procName)")

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo("public", progress: nil)
        let procedures = schemaInfo.procedures
        let functions = schemaInfo.functions

        XCTAssertTrue(
            procedures.contains { $0.name.caseInsensitiveCompare(procName) == .orderedSame },
            "Expected '\(procName)' to appear as a procedure"
        )
        XCTAssertFalse(
            functions.contains { $0.name.caseInsensitiveCompare(procName) == .orderedSame },
            "Procedure '\(procName)' should not appear as a function"
        )
    }

    func testProcedureWithParametersAppearsInSchemaInfo() async throws {
        let procName = uniqueName(prefix: "proc")
        try await execute("""
            CREATE PROCEDURE public.\(procName)(IN p_value INT)
            LANGUAGE plpgsql AS $$
            BEGIN
                RAISE NOTICE 'value: %', p_value;
            END;
            $$
        """)
        cleanupSQL("DROP PROCEDURE IF EXISTS public.\(procName)")

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo("public", progress: nil)
        IntegrationTestHelpers.assertContainsObject(
            schemaInfo.objects, name: procName, type: .procedure
        )
    }

    // MARK: - Functions Stay as Functions

    func testFunctionStaysAsFunctionNotProcedure() async throws {
        let funcName = uniqueName(prefix: "fn")
        try await postgresClient.admin.createFunction(
            name: funcName,
            parameters: [],
            returnType: "INT",
            body: "SELECT 42",
            language: .sql
        )
        cleanupSQL("DROP FUNCTION IF EXISTS public.\(funcName)()")

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo("public", progress: nil)
        let functions = schemaInfo.functions
        let procedures = schemaInfo.procedures

        XCTAssertTrue(
            functions.contains { $0.name.caseInsensitiveCompare(funcName) == .orderedSame },
            "Expected '\(funcName)' to appear as a function"
        )
        XCTAssertFalse(
            procedures.contains { $0.name.caseInsensitiveCompare(funcName) == .orderedSame },
            "Function '\(funcName)' should not appear as a procedure"
        )
    }

    // MARK: - Mixed Object Types in Same Schema

    func testMixedObjectTypesAllAppearCorrectly() async throws {
        let schemaName = uniqueName(prefix: "mix")
        try await postgresClient.admin.createSchema(name: schemaName)
        cleanupSQL("DROP SCHEMA IF EXISTS \(schemaName) CASCADE")

        let seqName = uniqueName(prefix: "seq")
        let enumName = uniqueName(prefix: "enum")
        let funcName = uniqueName(prefix: "fn")
        let procName = uniqueName(prefix: "proc")
        let tableName = uniqueName(prefix: "tbl")

        try await execute("CREATE SEQUENCE \(schemaName).\(seqName)")
        try await execute("CREATE TYPE \(schemaName).\(enumName) AS ENUM ('on', 'off')")
        try await execute("""
            CREATE FUNCTION \(schemaName).\(funcName)() RETURNS INT
            LANGUAGE SQL AS $$ SELECT 1; $$
        """)
        try await execute("""
            CREATE PROCEDURE \(schemaName).\(procName)()
            LANGUAGE SQL AS $$ SELECT 1; $$
        """)
        try await execute(
            "CREATE TABLE \(schemaName).\(tableName) (id SERIAL PRIMARY KEY)"
        )

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo(schemaName, progress: nil)

        IntegrationTestHelpers.assertContainsObject(
            schemaInfo.objects, name: seqName, type: .sequence
        )
        IntegrationTestHelpers.assertContainsObject(
            schemaInfo.objects, name: enumName, type: .type
        )
        IntegrationTestHelpers.assertContainsObject(
            schemaInfo.objects, name: funcName, type: .function
        )
        IntegrationTestHelpers.assertContainsObject(
            schemaInfo.objects, name: procName, type: .procedure
        )
        IntegrationTestHelpers.assertContainsObject(
            schemaInfo.objects, name: tableName, type: .table
        )
    }
}
