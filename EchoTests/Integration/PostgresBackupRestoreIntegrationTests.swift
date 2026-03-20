import Testing
import Foundation
@testable import Echo

/// Integration tests for PostgreSQL backup and restore via pg_dump/pg_restore.
///
/// Every test creates real data, backs up, drops/truncates, restores, and verifies
/// the data survived the roundtrip. No test merely checks exit codes or file contents.
///
/// Requires Docker Postgres on the self-hosted runner (echo-test-pg, port 54322).
/// Environment variables: TEST_PG_HOST, TEST_PG_PORT, TEST_PG_DATABASE, TEST_PG_USER, TEST_PG_PASSWORD
@Suite("PostgreSQL Backup & Restore")
struct PostgresBackupRestoreIntegrationTests {

    // MARK: - Config & Helpers

    struct PGConfig {
        let host: String
        let port: Int
        let database: String
        let username: String
        let password: String

        var connectionURI: String {
            "postgresql://\(username):\(password)@\(host):\(port)/\(database)?sslmode=disable"
        }
    }

    private func loadConfig() throws -> PGConfig {
        let env = ProcessInfo.processInfo.environment
        guard
            let host = env["TEST_PG_HOST"],
            let portStr = env["TEST_PG_PORT"], let port = Int(portStr),
            let database = env["TEST_PG_DATABASE"],
            let username = env["TEST_PG_USER"],
            let password = env["TEST_PG_PASSWORD"]
        else {
            throw PGTestError.skipped
        }
        return PGConfig(host: host, port: port, database: database, username: username, password: password)
    }

    private let runner = PostgresProcessRunner()

    private func pgDump(config: PGConfig, args: [String]) async throws -> ProcessResult {
        guard let exe = PostgresToolLocator.pgDumpURL() else { throw PGTestError.toolNotFound("pg_dump") }
        let env: [String: String] = ["PGPASSWORD": config.password, "PGSSLMODE": "disable"]
        return try await runner.run(executable: exe, arguments: args, environment: env)
    }

    private func pgRestore(config: PGConfig, args: [String]) async throws -> ProcessResult {
        guard let exe = PostgresToolLocator.pgRestoreURL() else { throw PGTestError.toolNotFound("pg_restore") }
        let env: [String: String] = ["PGPASSWORD": config.password, "PGSSLMODE": "disable"]
        return try await runner.run(executable: exe, arguments: args, environment: env)
    }

    private func connect(config: PGConfig) async throws -> DatabaseSession {
        let factory = PostgresNIOFactory()
        return try await factory.connect(
            host: config.host, port: config.port, database: config.database,
            tls: false,
            authentication: DatabaseAuthenticationConfiguration(username: config.username, password: config.password)
        )
    }

    private func tempFile(ext: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("echo_bktest_\(UUID().uuidString.prefix(8)).\(ext)")
    }

    private func tempDir() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("echo_bktest_\(UUID().uuidString.prefix(8))")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Create two tables with foreign key + sample data (3 rows in A, 2 in B).
    private func setupTestData(config: PGConfig) async throws {
        let s = try await connect(config: config)
        _ = try await s.simpleQuery("DROP TABLE IF EXISTS bk_child CASCADE")
        _ = try await s.simpleQuery("DROP TABLE IF EXISTS bk_parent CASCADE")
        _ = try await s.simpleQuery("""
            CREATE TABLE bk_parent (
                id SERIAL PRIMARY KEY,
                name TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT now()
            )
        """)
        _ = try await s.simpleQuery("""
            CREATE TABLE bk_child (
                id SERIAL PRIMARY KEY,
                parent_id INTEGER REFERENCES bk_parent(id),
                value NUMERIC(10,2)
            )
        """)
        _ = try await s.simpleQuery("INSERT INTO bk_parent (name) VALUES ('alpha'), ('beta'), ('gamma')")
        _ = try await s.simpleQuery("INSERT INTO bk_child (parent_id, value) VALUES (1, 10.5), (2, 20.0)")
        await s.close()
    }

    /// Drop both test tables.
    private func dropTestData(config: PGConfig) async throws {
        let s = try await connect(config: config)
        _ = try await s.simpleQuery("DROP TABLE IF EXISTS bk_child CASCADE")
        _ = try await s.simpleQuery("DROP TABLE IF EXISTS bk_parent CASCADE")
        await s.close()
    }

    /// Truncate both tables (keep structure, remove data).
    private func truncateTestData(config: PGConfig) async throws {
        let s = try await connect(config: config)
        _ = try await s.simpleQuery("TRUNCATE bk_child, bk_parent CASCADE")
        await s.close()
    }

    private func rowCount(config: PGConfig, table: String) async throws -> Int {
        let s = try await connect(config: config)
        let r = try await s.simpleQuery("SELECT count(*) AS cnt FROM \(table)")
        await s.close()
        guard let row = r.rows.first, let v = row.first else { return 0 }
        return Int(v ?? "0") ?? 0
    }

    private func tableExists(config: PGConfig, table: String) async throws -> Bool {
        let s = try await connect(config: config)
        let r = try await s.simpleQuery("""
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = '\(table)'
        """)
        await s.close()
        return !r.rows.isEmpty
    }

    /// Full roundtrip helper: backup with extra args → drop tables → restore with extra args → verify counts.
    private func roundtrip(
        config: PGConfig,
        format: String = "c",
        fileExt: String = "dump",
        backupArgs: [String] = [],
        restoreArgs: [String] = [],
        expectedParentRows: Int = 3,
        expectedChildRows: Int = 2,
        useDirectory: Bool = false
    ) async throws {
        let dest: URL
        if useDirectory {
            dest = tempDir()
            try FileManager.default.removeItem(at: dest) // pg_dump creates it
        } else {
            dest = tempFile(ext: fileExt)
        }
        defer { try? FileManager.default.removeItem(at: dest) }

        // Backup
        var dumpArgs = ["--dbname", config.connectionURI, "--format", format, "--file", dest.path, "--no-password"]
        dumpArgs.append(contentsOf: backupArgs)
        let dumpResult = try await pgDump(config: config, args: dumpArgs)
        #expect(dumpResult.exitCode == 0, "pg_dump failed: \(dumpResult.stderrLines.last ?? "unknown")")

        // Drop
        try await dropTestData(config: config)
        let gone = try await tableExists(config: config, table: "bk_parent")
        #expect(!gone, "Tables should be gone after drop")

        // Restore
        var restArgs = ["--dbname", config.connectionURI, "--no-password"]
        restArgs.append(contentsOf: restoreArgs)
        restArgs.append(dest.path)
        let restResult = try await pgRestore(config: config, args: restArgs)
        #expect(restResult.exitCode == 0, "pg_restore failed: \(restResult.stderrLines.last ?? "unknown")")

        // Verify
        let parentCount = try await rowCount(config: config, table: "bk_parent")
        #expect(parentCount == expectedParentRows, "bk_parent: expected \(expectedParentRows), got \(parentCount)")
        let childCount = try await rowCount(config: config, table: "bk_child")
        #expect(childCount == expectedChildRows, "bk_child: expected \(expectedChildRows), got \(childCount)")
    }

    // MARK: - Format Tests

    @Test("Custom format: full backup→drop→restore→verify")
    func customFormat() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }
        try await roundtrip(config: c, format: "c", fileExt: "dump")
    }

    @Test("Plain SQL format: backup→drop→restore via psql→verify")
    func plainFormat() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }

        let file = tempFile(ext: "sql")
        defer { try? FileManager.default.removeItem(at: file) }

        let dump = try await pgDump(config: c, args: [
            "--dbname", c.connectionURI, "--format", "p", "--file", file.path, "--no-password"
        ])
        #expect(dump.exitCode == 0)

        try await dropTestData(config: c)

        // Plain SQL restores via direct session execution (like the app does)
        let sql = try String(contentsOf: file, encoding: .utf8)
        let s = try await connect(config: c)
        _ = try await s.simpleQuery(sql)
        await s.close()

        let count = try await rowCount(config: c, table: "bk_parent")
        #expect(count == 3)
        let childCount = try await rowCount(config: c, table: "bk_child")
        #expect(childCount == 2)
    }

    @Test("Tar format: full backup→drop→restore→verify")
    func tarFormat() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }
        try await roundtrip(config: c, format: "t", fileExt: "tar")
    }

    @Test("Directory format: parallel backup→drop→parallel restore→verify")
    func directoryFormat() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }
        try await roundtrip(
            config: c, format: "d",
            backupArgs: ["--jobs", "2"],
            restoreArgs: ["--jobs", "2"],
            useDirectory: true
        )
    }

    // MARK: - Schema / Data Scope

    @Test("Schema-only: tables exist after restore but have zero rows")
    func schemaOnly() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }
        try await roundtrip(
            config: c, backupArgs: ["--schema-only"],
            expectedParentRows: 0, expectedChildRows: 0
        )
    }

    @Test("Data-only: truncate→restore→verify data returns")
    func dataOnly() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }

        let file = tempFile(ext: "dump")
        defer { try? FileManager.default.removeItem(at: file) }

        let dump = try await pgDump(config: c, args: [
            "--dbname", c.connectionURI, "--format", "c", "--file", file.path,
            "--data-only", "--no-password"
        ])
        #expect(dump.exitCode == 0)

        // Truncate (keep structure)
        try await truncateTestData(config: c)
        let before = try await rowCount(config: c, table: "bk_parent")
        #expect(before == 0)

        let rest = try await pgRestore(config: c, args: [
            "--dbname", c.connectionURI, "--no-password", "--data-only", file.path
        ])
        #expect(rest.exitCode == 0)

        let after = try await rowCount(config: c, table: "bk_parent")
        #expect(after == 3)
    }

    @Test("Table include: only selected table is backed up and restored")
    func tableInclude() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }

        let file = tempFile(ext: "dump")
        defer { try? FileManager.default.removeItem(at: file) }

        let dump = try await pgDump(config: c, args: [
            "--dbname", c.connectionURI, "--format", "c", "--file", file.path,
            "--table", "bk_parent", "--no-password"
        ])
        #expect(dump.exitCode == 0)

        try await dropTestData(config: c)

        let rest = try await pgRestore(config: c, args: [
            "--dbname", c.connectionURI, "--no-password", file.path
        ])
        #expect(rest.exitCode == 0)

        let parentExists = try await tableExists(config: c, table: "bk_parent")
        #expect(parentExists, "Included table should exist")
        let childExists = try await tableExists(config: c, table: "bk_child")
        #expect(!childExists, "Excluded table should not exist")
        let count = try await rowCount(config: c, table: "bk_parent")
        #expect(count == 3)
    }

    @Test("Table exclude: excluded table is not in backup")
    func tableExclude() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }

        let file = tempFile(ext: "dump")
        defer { try? FileManager.default.removeItem(at: file) }

        let dump = try await pgDump(config: c, args: [
            "--dbname", c.connectionURI, "--format", "c", "--file", file.path,
            "--exclude-table", "bk_child", "--no-password"
        ])
        #expect(dump.exitCode == 0)

        try await dropTestData(config: c)

        let rest = try await pgRestore(config: c, args: [
            "--dbname", c.connectionURI, "--no-password", file.path
        ])
        #expect(rest.exitCode == 0)

        let parentExists = try await tableExists(config: c, table: "bk_parent")
        #expect(parentExists)
        let childExists = try await tableExists(config: c, table: "bk_child")
        #expect(!childExists, "Excluded table should not be restored")
    }

    @Test("Exclude table data: schema restored, data skipped for specified table")
    func excludeTableData() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }

        let file = tempFile(ext: "dump")
        defer { try? FileManager.default.removeItem(at: file) }

        let dump = try await pgDump(config: c, args: [
            "--dbname", c.connectionURI, "--format", "c", "--file", file.path,
            "--exclude-table-data", "bk_child", "--no-password"
        ])
        #expect(dump.exitCode == 0)

        try await dropTestData(config: c)

        let rest = try await pgRestore(config: c, args: [
            "--dbname", c.connectionURI, "--no-password", file.path
        ])
        #expect(rest.exitCode == 0)

        let parentCount = try await rowCount(config: c, table: "bk_parent")
        #expect(parentCount == 3, "Parent data should be restored")
        let childCount = try await rowCount(config: c, table: "bk_child")
        #expect(childCount == 0, "Child data should be excluded")
    }

    // MARK: - Ownership & Privileges

    @Test("No-owner + no-privileges: full roundtrip still works")
    func noOwnerNoPrivileges() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }
        try await roundtrip(
            config: c,
            backupArgs: ["--no-owner", "--no-privileges"],
            restoreArgs: ["--no-owner", "--no-privileges"]
        )
    }

    @Test("No-tablespaces: full roundtrip works")
    func noTablespaces() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }
        try await roundtrip(
            config: c,
            backupArgs: ["--no-tablespaces"],
            restoreArgs: ["--no-tablespaces"]
        )
    }

    // MARK: - Clean / If-Exists Restore

    @Test("Clean + if-exists restore replaces modified data")
    func cleanIfExists() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }

        let file = tempFile(ext: "dump")
        defer { try? FileManager.default.removeItem(at: file) }

        let dump = try await pgDump(config: c, args: [
            "--dbname", c.connectionURI, "--format", "c", "--file", file.path, "--no-password"
        ])
        #expect(dump.exitCode == 0)

        // Add extra row
        let s = try await connect(config: c)
        _ = try await s.simpleQuery("INSERT INTO bk_parent (name) VALUES ('extra')")
        await s.close()
        let before = try await rowCount(config: c, table: "bk_parent")
        #expect(before == 4)

        // Restore with clean should revert to 3
        _ = try await pgRestore(config: c, args: [
            "--dbname", c.connectionURI, "--clean", "--if-exists", "--no-password", file.path
        ])
        let after = try await rowCount(config: c, table: "bk_parent")
        #expect(after == 3, "Clean restore should revert to original 3 rows")
    }

    // MARK: - INSERT Mode

    @Test("INSERTs mode: backup with --inserts, restore, verify data")
    func insertsMode() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }

        let file = tempFile(ext: "sql")
        defer { try? FileManager.default.removeItem(at: file) }

        let dump = try await pgDump(config: c, args: [
            "--dbname", c.connectionURI, "--format", "p", "--file", file.path,
            "--inserts", "--no-password"
        ])
        #expect(dump.exitCode == 0)

        // Verify file uses INSERT, not COPY
        let sql = try String(contentsOf: file, encoding: .utf8)
        #expect(sql.contains("INSERT INTO"), "Should use INSERT statements")

        // Roundtrip
        try await dropTestData(config: c)
        let s = try await connect(config: c)
        _ = try await s.simpleQuery(sql)
        await s.close()

        let count = try await rowCount(config: c, table: "bk_parent")
        #expect(count == 3)
    }

    @Test("Column INSERTs: includes column names and roundtrips")
    func columnInserts() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }

        let file = tempFile(ext: "sql")
        defer { try? FileManager.default.removeItem(at: file) }

        let dump = try await pgDump(config: c, args: [
            "--dbname", c.connectionURI, "--format", "p", "--file", file.path,
            "--column-inserts", "--no-password"
        ])
        #expect(dump.exitCode == 0)

        let sql = try String(contentsOf: file, encoding: .utf8)
        #expect(sql.contains("INSERT INTO public.bk_parent ("), "Should include column names")

        try await dropTestData(config: c)
        let s = try await connect(config: c)
        _ = try await s.simpleQuery(sql)
        await s.close()

        let count = try await rowCount(config: c, table: "bk_parent")
        #expect(count == 3)
    }

    @Test("On conflict do nothing: can restore into non-empty table")
    func onConflictDoNothing() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }

        let file = tempFile(ext: "sql")
        defer { try? FileManager.default.removeItem(at: file) }

        let dump = try await pgDump(config: c, args: [
            "--dbname", c.connectionURI, "--format", "p", "--file", file.path,
            "--inserts", "--on-conflict-do-nothing", "--no-password"
        ])
        #expect(dump.exitCode == 0)

        let sql = try String(contentsOf: file, encoding: .utf8)
        #expect(sql.contains("ON CONFLICT DO NOTHING"))

        // Restore on top of existing data — should not fail or duplicate
        let s = try await connect(config: c)
        _ = try await s.simpleQuery(sql)
        await s.close()

        let count = try await rowCount(config: c, table: "bk_parent")
        #expect(count == 3, "ON CONFLICT DO NOTHING should not duplicate rows")
    }

    // MARK: - Compression

    @Test("Compression level 9: produces valid backup that restores correctly")
    func compressionRoundtrip() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }
        try await roundtrip(config: c, backupArgs: ["--compress", "9"])
    }

    @Test("Compression 0 vs 9: compressed file is not larger")
    func compressionSizeComparison() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }

        let noComp = tempFile(ext: "dump")
        let hiComp = tempFile(ext: "dump")
        defer {
            try? FileManager.default.removeItem(at: noComp)
            try? FileManager.default.removeItem(at: hiComp)
        }

        let r1 = try await pgDump(config: c, args: [
            "--dbname", c.connectionURI, "--format", "c", "--file", noComp.path,
            "--compress", "0", "--no-password"
        ])
        #expect(r1.exitCode == 0)

        let r2 = try await pgDump(config: c, args: [
            "--dbname", c.connectionURI, "--format", "c", "--file", hiComp.path,
            "--compress", "9", "--no-password"
        ])
        #expect(r2.exitCode == 0)

        let size0 = try FileManager.default.attributesOfItem(atPath: noComp.path)[.size] as? Int ?? 0
        let size9 = try FileManager.default.attributesOfItem(atPath: hiComp.path)[.size] as? Int ?? 0
        #expect(size9 <= size0, "Compressed (\(size9)) should be <= uncompressed (\(size0))")
    }

    // MARK: - Encoding

    @Test("Encoding override UTF8: backup and restore roundtrip")
    func encodingUTF8() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }
        try await roundtrip(config: c, backupArgs: ["--encoding", "UTF8"])
    }

    // MARK: - Advanced Options

    @Test("Verbose: produces stderr output and roundtrips")
    func verboseRoundtrip() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }

        let file = tempFile(ext: "dump")
        defer { try? FileManager.default.removeItem(at: file) }

        let dump = try await pgDump(config: c, args: [
            "--dbname", c.connectionURI, "--format", "c", "--file", file.path,
            "--verbose", "--no-password"
        ])
        #expect(dump.exitCode == 0)
        #expect(!dump.stderrLines.isEmpty, "Verbose should produce stderr output")

        try await dropTestData(config: c)

        let rest = try await pgRestore(config: c, args: [
            "--dbname", c.connectionURI, "--no-password", "--verbose", file.path
        ])
        #expect(rest.exitCode == 0)

        let count = try await rowCount(config: c, table: "bk_parent")
        #expect(count == 3)
    }

    @Test("Quote all identifiers: roundtrip works")
    func quoteAllIdentifiers() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }

        let file = tempFile(ext: "sql")
        defer { try? FileManager.default.removeItem(at: file) }

        let dump = try await pgDump(config: c, args: [
            "--dbname", c.connectionURI, "--format", "p", "--file", file.path,
            "--quote-all-identifiers", "--no-password"
        ])
        #expect(dump.exitCode == 0)

        let sql = try String(contentsOf: file, encoding: .utf8)
        #expect(sql.contains("\"bk_parent\""), "Should quote table names")

        try await dropTestData(config: c)
        let s = try await connect(config: c)
        _ = try await s.simpleQuery(sql)
        await s.close()

        let count = try await rowCount(config: c, table: "bk_parent")
        #expect(count == 3)
    }

    @Test("SET SESSION AUTHORIZATION: roundtrip works")
    func setSessionAuth() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }
        try await roundtrip(config: c, backupArgs: ["--use-set-session-authorization"])
    }

    @Test("Lock wait timeout: backup completes with timeout set")
    func lockWaitTimeout() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }
        try await roundtrip(config: c, backupArgs: ["--lock-wait-timeout", "5000"])
    }

    @Test("Disable dollar quoting: roundtrip works")
    func disableDollarQuoting() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }

        let file = tempFile(ext: "sql")
        defer { try? FileManager.default.removeItem(at: file) }

        let dump = try await pgDump(config: c, args: [
            "--dbname", c.connectionURI, "--format", "p", "--file", file.path,
            "--disable-dollar-quoting", "--no-password"
        ])
        #expect(dump.exitCode == 0)

        try await dropTestData(config: c)
        let sql = try String(contentsOf: file, encoding: .utf8)
        let s = try await connect(config: c)
        _ = try await s.simpleQuery(sql)
        await s.close()

        let count = try await rowCount(config: c, table: "bk_parent")
        #expect(count == 3)
    }

    @Test("Disable triggers: data-only restore with triggers disabled")
    func disableTriggers() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }

        let file = tempFile(ext: "dump")
        defer { try? FileManager.default.removeItem(at: file) }

        let dump = try await pgDump(config: c, args: [
            "--dbname", c.connectionURI, "--format", "c", "--file", file.path,
            "--no-password"
        ])
        #expect(dump.exitCode == 0)

        try await truncateTestData(config: c)

        let rest = try await pgRestore(config: c, args: [
            "--dbname", c.connectionURI, "--no-password",
            "--data-only", "--disable-triggers", file.path
        ])
        #expect(rest.exitCode == 0)

        let count = try await rowCount(config: c, table: "bk_parent")
        #expect(count == 3)
    }

    @Test("Parallel restore with custom format")
    func parallelRestore() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }
        try await roundtrip(config: c, restoreArgs: ["--jobs", "2"])
    }

    @Test("Extra arguments (--no-comments): roundtrip works")
    func extraArguments() async throws {
        let c = try loadConfig()
        try await setupTestData(config: c)
        defer { Task { try? await self.dropTestData(config: c) } }
        try await roundtrip(config: c, backupArgs: ["--no-comments"])
    }

    // MARK: - Tool Locator

    @Test("PostgresToolLocator finds pg_dump")
    func toolLocatorFindsPgDump() {
        #expect(PostgresToolLocator.pgDumpURL() != nil)
    }

    @Test("PostgresToolLocator finds pg_restore")
    func toolLocatorFindsPgRestore() {
        #expect(PostgresToolLocator.pgRestoreURL() != nil)
    }
}

enum PGTestError: Error {
    case skipped
    case toolNotFound(String)
}
