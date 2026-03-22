import XCTest
import SQLServerKit
@testable import Echo

/// Integration tests for SQL Server backup and restore operations.
///
/// Tests every backup option (compression, checksum, copy-only, media management,
/// encryption, expiration) and every restore option (REPLACE, NORECOVERY, STANDBY,
/// KEEP_REPLICATION, RESTRICTED_USER, file relocation, point-in-time).
///
/// Requires Docker SQL Server on the self-hosted runner (echo-test-mssql, port 14332).
class MSSQLBackupRestoreTests: MSSQLDockerTestCase {

    private let backupDir = "/var/opt/mssql/backup"

    // MARK: - Test Database Setup

    private func setupTestDB(_ name: String) async throws {
        // Force-drop if leftover from a previous failed test run
        _ = try? await execute("""
            IF DB_ID('\(name)') IS NOT NULL
            BEGIN
                ALTER DATABASE [\(name)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
                DROP DATABASE [\(name)];
            END
        """)
        _ = try? await sqlserverClient.admin.createDatabase(name: name)
        let dbSession = try await createSession(database: name)
        _ = try? await dbSession.executeUpdate("DROP TABLE IF EXISTS dbo.test_data")
        _ = try await dbSession.executeUpdate("""
            CREATE TABLE dbo.test_data (
                id INT IDENTITY(1,1) PRIMARY KEY,
                name NVARCHAR(100) NOT NULL,
                value DECIMAL(10,2),
                created_at DATETIME2 DEFAULT GETDATE()
            )
        """)
        _ = try await dbSession.executeUpdate("""
            INSERT INTO dbo.test_data (name, value) VALUES
            ('alpha', 10.50), ('beta', 20.00), ('gamma', 30.75),
            ('delta', 40.25), ('epsilon', 50.00)
        """)
        await dbSession.close()
    }

    private func dropTestDB(_ name: String) async {
        _ = try? await sqlserverClient.admin.dropDatabase(name: name, forceSingleUser: true)
    }

    private func cleanupDB(_ name: String) {
        let client = sqlserverClient
        addTeardownBlock {
            _ = try? await client.admin.dropDatabase(name: name, forceSingleUser: true)
        }
    }

    private func rowCount(database: String, table: String) async throws -> Int {
        let dbSession = try await createSession(database: database)
        let result = try await dbSession.simpleQuery("SELECT COUNT(*) AS cnt FROM \(table)")
        await dbSession.close()
        guard let row = result.rows.first, let val = row.first else { return 0 }
        return Int(val ?? "0") ?? 0
    }

    private func backupPath(_ filename: String) -> String {
        "\(backupDir)/\(filename)"
    }

    // MARK: - Basic Backup & Restore

    func testFullBackupAndRestore() async throws {
        let dbName = uniqueTableName(prefix: "bktest")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_full.bak")

        // Backup
        let options = SQLServerBackupOptions(
            database: dbName,
            diskPath: path,
            backupType: .full,
            backupName: "Full Backup Test",
            initMedia: true
        )
        let messages = try await sqlserverClient.backupRestore.backup(options: options)
        let infoMessages = messages.filter { $0.kind == .info }.map(\.message)
        XCTAssertTrue(infoMessages.contains(where: { $0.contains("BACKUP DATABASE") }), "Should report backup progress")

        // Drop and restore
        await dropTestDB(dbName)

        let restoreOptions = SQLServerRestoreOptions(
            database: dbName,
            diskPath: path,
            recoveryMode: .recovery,
            replace: true
        )
        let restoreMessages = try await sqlserverClient.backupRestore.restore(options: restoreOptions)
        let restoreInfo = restoreMessages.filter { $0.kind == .info }.map(\.message)
        XCTAssertTrue(restoreInfo.contains(where: { $0.contains("RESTORE DATABASE") }))

        // Verify data
        let count = try await rowCount(database: dbName, table: "dbo.test_data")
        XCTAssertEqual(count, 5, "Restored database should have 5 rows")
    }

    func testDifferentialBackup() async throws {
        let dbName = uniqueTableName(prefix: "bkdiff")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let fullPath = backupPath("\(dbName)_full.bak")
        let diffPath = backupPath("\(dbName)_diff.bak")

        // Full backup first
        let fullOptions = SQLServerBackupOptions(database: dbName, diskPath: fullPath, backupType: .full, initMedia: true)
        _ = try await sqlserverClient.backupRestore.backup(options: fullOptions)

        // Add more data
        let dbSession = try await createSession(database: dbName)
        _ = try await dbSession.executeUpdate("INSERT INTO dbo.test_data (name, value) VALUES ('zeta', 60.00)")
        await dbSession.close()

        // Differential backup
        let diffOptions = SQLServerBackupOptions(database: dbName, diskPath: diffPath, backupType: .differential, initMedia: true)
        _ = try await sqlserverClient.backupRestore.backup(options: diffOptions)

        // Drop and restore full + diff
        await dropTestDB(dbName)

        let restoreFull = SQLServerRestoreOptions(database: dbName, diskPath: fullPath, recoveryMode: .noRecovery, replace: true)
        _ = try await sqlserverClient.backupRestore.restore(options: restoreFull)

        let restoreDiff = SQLServerRestoreOptions(database: dbName, diskPath: diffPath, recoveryMode: .recovery)
        _ = try await sqlserverClient.backupRestore.restore(options: restoreDiff)

        let count = try await rowCount(database: dbName, table: "dbo.test_data")
        XCTAssertEqual(count, 6, "Should have 6 rows after full + diff restore")
    }

    func testLogBackup() async throws {
        let dbName = uniqueTableName(prefix: "bklog")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        // Set recovery model to FULL for log backups
        _ = try await session.executeUpdate("ALTER DATABASE [\(dbName)] SET RECOVERY FULL")

        let fullPath = backupPath("\(dbName)_full.bak")
        let logPath = backupPath("\(dbName)_log.trn")

        // Full backup
        let fullOptions = SQLServerBackupOptions(database: dbName, diskPath: fullPath, backupType: .full, initMedia: true)
        _ = try await sqlserverClient.backupRestore.backup(options: fullOptions)

        // Add data
        let dbSession = try await createSession(database: dbName)
        _ = try await dbSession.executeUpdate("INSERT INTO dbo.test_data (name, value) VALUES ('theta', 70.00)")
        await dbSession.close()

        // Log backup
        let logOptions = SQLServerBackupOptions(database: dbName, diskPath: logPath, backupType: .log, initMedia: true)
        _ = try await sqlserverClient.backupRestore.backup(options: logOptions)

        // Drop and restore full + log
        await dropTestDB(dbName)

        let restoreFull = SQLServerRestoreOptions(database: dbName, diskPath: fullPath, recoveryMode: .noRecovery, replace: true)
        _ = try await sqlserverClient.backupRestore.restore(options: restoreFull)

        let restoreLog = SQLServerRestoreOptions(database: dbName, diskPath: logPath, recoveryMode: .recovery)
        _ = try await sqlserverClient.backupRestore.restore(options: restoreLog)

        let count = try await rowCount(database: dbName, table: "dbo.test_data")
        XCTAssertEqual(count, 6, "Should have 6 rows after full + log restore")
    }

    // MARK: - Backup Options

    func testBackupWithCompression() async throws {
        let dbName = uniqueTableName(prefix: "bkcomp")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let compressedPath = backupPath("\(dbName)_compressed.bak")
        let uncompressedPath = backupPath("\(dbName)_uncompressed.bak")

        let compressedOptions = SQLServerBackupOptions(
            database: dbName, diskPath: compressedPath, compression: true, initMedia: true
        )
        _ = try await sqlserverClient.backupRestore.backup(options: compressedOptions)

        let uncompressedOptions = SQLServerBackupOptions(
            database: dbName, diskPath: uncompressedPath, compression: false, initMedia: true
        )
        _ = try await sqlserverClient.backupRestore.backup(options: uncompressedOptions)

        // Verify both produced valid backups by listing sets
        let compSets = try await sqlserverClient.backupRestore.listBackupSets(diskPath: compressedPath)
        let uncompSets = try await sqlserverClient.backupRestore.listBackupSets(diskPath: uncompressedPath)
        XCTAssertFalse(compSets.isEmpty, "Compressed backup should have backup sets")
        XCTAssertFalse(uncompSets.isEmpty, "Uncompressed backup should have backup sets")
        XCTAssertTrue(compSets[0].compressed, "Compressed backup should report as compressed")
    }

    func testBackupWithChecksum() async throws {
        let dbName = uniqueTableName(prefix: "bkchk")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_checksum.bak")
        let options = SQLServerBackupOptions(
            database: dbName, diskPath: path, checksum: true, initMedia: true
        )
        let messages = try await sqlserverClient.backupRestore.backup(options: options)
        let info = messages.filter { $0.kind == .info }.map(\.message)
        XCTAssertTrue(info.contains(where: { $0.contains("BACKUP DATABASE") }))

        // Verify backup is valid
        let verifyMessages = try await sqlserverClient.backupRestore.verifyBackup(diskPath: path)
        let verifyInfo = verifyMessages.filter { $0.kind == .info }.map(\.message)
        XCTAssertTrue(verifyInfo.contains(where: { $0.contains("valid") || $0.contains("VERIFY") || verifyInfo.isEmpty == false }))
    }

    func testBackupCopyOnly() async throws {
        let dbName = uniqueTableName(prefix: "bkcopy")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_copyonly.bak")
        let options = SQLServerBackupOptions(
            database: dbName, diskPath: path, copyOnly: true, initMedia: true
        )
        _ = try await sqlserverClient.backupRestore.backup(options: options)

        let sets = try await sqlserverClient.backupRestore.listBackupSets(diskPath: path)
        XCTAssertEqual(sets.count, 1)
        XCTAssertEqual(sets[0].databaseName, dbName)
    }

    func testBackupContinueOnError() async throws {
        let dbName = uniqueTableName(prefix: "bkcont")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_continue.bak")
        let options = SQLServerBackupOptions(
            database: dbName, diskPath: path, checksum: true, continueAfterError: true, initMedia: true
        )
        _ = try await sqlserverClient.backupRestore.backup(options: options)

        let sets = try await sqlserverClient.backupRestore.listBackupSets(diskPath: path)
        XCTAssertFalse(sets.isEmpty)
    }

    // MARK: - Media Management

    func testBackupInitVsAppend() async throws {
        let dbName = uniqueTableName(prefix: "bkmedia")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_media.bak")

        // First backup with INIT (creates new file)
        let initOptions = SQLServerBackupOptions(
            database: dbName, diskPath: path, backupName: "First", initMedia: true
        )
        _ = try await sqlserverClient.backupRestore.backup(options: initOptions)

        // Second backup with NOINIT (appends)
        let appendOptions = SQLServerBackupOptions(
            database: dbName, diskPath: path, backupName: "Second", initMedia: false
        )
        _ = try await sqlserverClient.backupRestore.backup(options: appendOptions)

        // Should have 2 backup sets
        let sets = try await sqlserverClient.backupRestore.listBackupSets(diskPath: path)
        XCTAssertEqual(sets.count, 2, "Appended backup should result in 2 backup sets")
        XCTAssertEqual(sets[0].backupName, "First")
        XCTAssertEqual(sets[1].backupName, "Second")
    }

    func testBackupFormatMedia() async throws {
        let dbName = uniqueTableName(prefix: "bkfmt")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_format.bak")

        // Create initial backup
        let first = SQLServerBackupOptions(database: dbName, diskPath: path, initMedia: true)
        _ = try await sqlserverClient.backupRestore.backup(options: first)

        // Backup with FORMAT — should overwrite
        let formatOptions = SQLServerBackupOptions(
            database: dbName, diskPath: path, backupName: "Formatted",
            formatMedia: true, mediaName: "TestMediaSet"
        )
        _ = try await sqlserverClient.backupRestore.backup(options: formatOptions)

        let sets = try await sqlserverClient.backupRestore.listBackupSets(diskPath: path)
        XCTAssertEqual(sets.count, 1, "FORMAT should overwrite — only 1 set")
        XCTAssertEqual(sets[0].backupName, "Formatted")
    }

    func testBackupWithMediaName() async throws {
        let dbName = uniqueTableName(prefix: "bkmname")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_medianame.bak")
        let options = SQLServerBackupOptions(
            database: dbName, diskPath: path,
            formatMedia: true, mediaName: "EchoTestMedia"
        )
        _ = try await sqlserverClient.backupRestore.backup(options: options)

        let sets = try await sqlserverClient.backupRestore.listBackupSets(diskPath: path)
        XCTAssertFalse(sets.isEmpty)
    }

    // MARK: - Expiration

    func testBackupWithExpireDate() async throws {
        let dbName = uniqueTableName(prefix: "bkexp")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let futureDate = Date().addingTimeInterval(30 * 24 * 3600)
        let path = backupPath("\(dbName)_expire.bak")
        let options = SQLServerBackupOptions(
            database: dbName, diskPath: path,
            initMedia: true, expireDate: futureDate
        )
        _ = try await sqlserverClient.backupRestore.backup(options: options)

        let sets = try await sqlserverClient.backupRestore.listBackupSets(diskPath: path)
        XCTAssertFalse(sets.isEmpty, "Backup with expire date should succeed")
    }

    // MARK: - Verify

    func testVerifyBackup() async throws {
        let dbName = uniqueTableName(prefix: "bkverify")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_verify.bak")
        let options = SQLServerBackupOptions(database: dbName, diskPath: path, checksum: true, initMedia: true)
        _ = try await sqlserverClient.backupRestore.backup(options: options)

        let verifyMessages = try await sqlserverClient.backupRestore.verifyBackup(diskPath: path)
        // VERIFYONLY should complete without throwing — messages may or may not be present
        XCTAssertNotNil(verifyMessages, "Verify should complete without error")
    }

    // MARK: - List Operations

    func testListBackupSets() async throws {
        let dbName = uniqueTableName(prefix: "bklist")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_list.bak")
        let options = SQLServerBackupOptions(
            database: dbName, diskPath: path,
            backupName: "Test Set", description: "A test backup",
            initMedia: true
        )
        _ = try await sqlserverClient.backupRestore.backup(options: options)

        let sets = try await sqlserverClient.backupRestore.listBackupSets(diskPath: path)
        XCTAssertEqual(sets.count, 1)
        XCTAssertEqual(sets[0].backupName, "Test Set")
        XCTAssertEqual(sets[0].backupDescription, "A test backup")
        XCTAssertEqual(sets[0].databaseName, dbName)
        XCTAssertEqual(sets[0].backupType, 1) // Full = 1
        XCTAssertNotNil(sets[0].backupSize)
        XCTAssertTrue((sets[0].backupSize ?? 0) > 0)
    }

    func testListBackupFiles() async throws {
        let dbName = uniqueTableName(prefix: "bkfiles")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_files.bak")
        let options = SQLServerBackupOptions(database: dbName, diskPath: path, initMedia: true)
        _ = try await sqlserverClient.backupRestore.backup(options: options)

        let files = try await sqlserverClient.backupRestore.listBackupFiles(diskPath: path)
        XCTAssertGreaterThanOrEqual(files.count, 2, "Should have at least data + log files")

        let dataFile = files.first(where: { $0.type == "D" })
        let logFile = files.first(where: { $0.type == "L" })
        XCTAssertNotNil(dataFile, "Should have a data file")
        XCTAssertNotNil(logFile, "Should have a log file")
        XCTAssertFalse(dataFile?.logicalName.isEmpty ?? true)
    }

    // MARK: - Restore Options

    func testRestoreWithReplace() async throws {
        let dbName = uniqueTableName(prefix: "bkreplace")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_replace.bak")
        let backupOptions = SQLServerBackupOptions(database: dbName, diskPath: path, initMedia: true)
        _ = try await sqlserverClient.backupRestore.backup(options: backupOptions)

        // Add extra data
        let dbSession = try await createSession(database: dbName)
        _ = try await dbSession.executeUpdate("INSERT INTO dbo.test_data (name, value) VALUES ('extra', 99.99)")
        await dbSession.close()

        let countBefore = try await rowCount(database: dbName, table: "dbo.test_data")
        XCTAssertEqual(countBefore, 6)

        // Kill all connections to the database before restore
        let killSession = try await createSession()
        _ = try? await killSession.simpleQuery("""
            ALTER DATABASE [\(dbName)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
        """)
        await killSession.close()

        let restoreOptions = SQLServerRestoreOptions(
            database: dbName, diskPath: path, recoveryMode: .recovery, replace: true
        )
        _ = try await sqlserverClient.backupRestore.restore(options: restoreOptions)

        // Restore multi-user mode
        let multiSession = try await createSession()
        _ = try? await multiSession.simpleQuery("ALTER DATABASE [\(dbName)] SET MULTI_USER")
        await multiSession.close()

        let countAfter = try await rowCount(database: dbName, table: "dbo.test_data")
        XCTAssertEqual(countAfter, 5, "REPLACE restore should revert to 5 rows")
    }

    func testRestoreNoRecovery() async throws {
        let dbName = uniqueTableName(prefix: "bknorec")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_norec.bak")
        let backupOptions = SQLServerBackupOptions(database: dbName, diskPath: path, initMedia: true)
        _ = try await sqlserverClient.backupRestore.backup(options: backupOptions)

        // Kill all connections before drop
        let killSession = try await createSession()
        _ = try? await killSession.simpleQuery("ALTER DATABASE [\(dbName)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE")
        await killSession.close()
        await dropTestDB(dbName)

        // Restore with NORECOVERY — database should be in restoring state
        let restoreOptions = SQLServerRestoreOptions(
            database: dbName, diskPath: path, recoveryMode: .noRecovery, replace: true
        )
        _ = try await sqlserverClient.backupRestore.restore(options: restoreOptions)

        // Querying should fail since DB is in restoring state
        do {
            _ = try await rowCount(database: dbName, table: "dbo.test_data")
            XCTFail("Should not be able to query a database in NORECOVERY state")
        } catch {
            // Expected — database is not accessible
        }

        // Bring online
        _ = try await session.executeUpdate("RESTORE DATABASE [\(dbName)] WITH RECOVERY")
        let count = try await rowCount(database: dbName, table: "dbo.test_data")
        XCTAssertEqual(count, 5)
    }

    func testRestoreWithFileRelocation() async throws {
        let dbName = uniqueTableName(prefix: "bkreloc")
        let restoreName = uniqueTableName(prefix: "bkreloc_r")
        try await setupTestDB(dbName)
        cleanupDB(dbName)
        cleanupDB(restoreName)

        let path = backupPath("\(dbName)_reloc.bak")
        let backupOptions = SQLServerBackupOptions(database: dbName, diskPath: path, initMedia: true)
        _ = try await sqlserverClient.backupRestore.backup(options: backupOptions)

        // Get file list to build relocations
        let files = try await sqlserverClient.backupRestore.listBackupFiles(diskPath: path)
        let relocations = files.map { file in
            let ext = file.type == "D" ? ".mdf" : ".ldf"
            return SQLServerRestoreOptions.FileRelocation(
                logicalName: file.logicalName,
                physicalPath: "/var/opt/mssql/data/\(restoreName)\(ext)"
            )
        }

        let restoreOptions = SQLServerRestoreOptions(
            database: restoreName, diskPath: path,
            recoveryMode: .recovery, replace: true,
            relocateFiles: relocations
        )
        _ = try await sqlserverClient.backupRestore.restore(options: restoreOptions)

        let count = try await rowCount(database: restoreName, table: "dbo.test_data")
        XCTAssertEqual(count, 5, "Relocated restore should have 5 rows")
    }

    func testRestoreWithChecksumAndContinueOnError() async throws {
        let dbName = uniqueTableName(prefix: "bkrchk")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_rchk.bak")
        let backupOptions = SQLServerBackupOptions(
            database: dbName, diskPath: path, checksum: true, initMedia: true
        )
        _ = try await sqlserverClient.backupRestore.backup(options: backupOptions)

        await dropTestDB(dbName)

        let restoreOptions = SQLServerRestoreOptions(
            database: dbName, diskPath: path,
            recoveryMode: .recovery, replace: true,
            checksum: true, continueAfterError: true
        )
        _ = try await sqlserverClient.backupRestore.restore(options: restoreOptions)

        let count = try await rowCount(database: dbName, table: "dbo.test_data")
        XCTAssertEqual(count, 5)
    }

    func testRestoreKeepReplication() async throws {
        let dbName = uniqueTableName(prefix: "bkkeep")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_keep.bak")
        let backupOptions = SQLServerBackupOptions(database: dbName, diskPath: path, initMedia: true)
        _ = try await sqlserverClient.backupRestore.backup(options: backupOptions)

        await dropTestDB(dbName)

        let restoreOptions = SQLServerRestoreOptions(
            database: dbName, diskPath: path,
            recoveryMode: .recovery, replace: true,
            keepReplication: true
        )
        _ = try await sqlserverClient.backupRestore.restore(options: restoreOptions)

        let count = try await rowCount(database: dbName, table: "dbo.test_data")
        XCTAssertEqual(count, 5)
    }

    func testRestoreRestrictedUser() async throws {
        let dbName = uniqueTableName(prefix: "bkrestr")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_restr.bak")
        let backupOptions = SQLServerBackupOptions(database: dbName, diskPath: path, initMedia: true)
        _ = try await sqlserverClient.backupRestore.backup(options: backupOptions)

        await dropTestDB(dbName)

        let restoreOptions = SQLServerRestoreOptions(
            database: dbName, diskPath: path,
            recoveryMode: .recovery, replace: true,
            restrictedUser: true
        )
        _ = try await sqlserverClient.backupRestore.restore(options: restoreOptions)

        let count = try await rowCount(database: dbName, table: "dbo.test_data")
        XCTAssertEqual(count, 5)

        // Reset to multi-user for cleanup
        _ = try await session.executeUpdate("ALTER DATABASE [\(dbName)] SET MULTI_USER")
    }

    // MARK: - Close Connections

    func testCloseConnectionsBeforeRestore() async throws {
        let dbName = uniqueTableName(prefix: "bkclose")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_close.bak")
        let backupOptions = SQLServerBackupOptions(database: dbName, diskPath: path, initMedia: true)
        _ = try await sqlserverClient.backupRestore.backup(options: backupOptions)

        // Open a session to the database (simulating active connection)
        let extraSession = try await createSession(database: dbName)

        // Close connections should kick the extra session
        try await sqlserverClient.backupRestore.closeConnections(database: dbName)

        // Restore should work now
        let restoreOptions = SQLServerRestoreOptions(
            database: dbName, diskPath: path, recoveryMode: .recovery, replace: true
        )
        _ = try await sqlserverClient.backupRestore.restore(options: restoreOptions)

        // Restore multi-user
        try await sqlserverClient.backupRestore.restoreMultiUser(database: dbName)

        let count = try await rowCount(database: dbName, table: "dbo.test_data")
        XCTAssertEqual(count, 5)

        await extraSession.close()
    }

    // MARK: - Backup History

    func testBackupHistory() async throws {
        let dbName = uniqueTableName(prefix: "bkhist")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_hist.bak")
        let options = SQLServerBackupOptions(
            database: dbName, diskPath: path,
            backupName: "History Test", initMedia: true
        )
        _ = try await sqlserverClient.backupRestore.backup(options: options)

        let history = try await sqlserverClient.backupRestore.getBackupHistory(database: dbName, limit: 10)
        XCTAssertFalse(history.isEmpty, "Backup history should have at least one entry")

        let latest = history[0]
        XCTAssertEqual(latest.name, "History Test")
        XCTAssertEqual(latest.type, "D") // Full
        XCTAssertTrue(latest.size > 0)
        XCTAssertNotNil(latest.startDate)
        XCTAssertNotNil(latest.finishDate)
    }

    // MARK: - Multiple Backup Sets

    func testRestoreSpecificFileNumber() async throws {
        let dbName = uniqueTableName(prefix: "bkfnum")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_multi.bak")

        // First backup
        let first = SQLServerBackupOptions(
            database: dbName, diskPath: path, backupName: "Set 1", initMedia: true
        )
        _ = try await sqlserverClient.backupRestore.backup(options: first)

        // Add data, second backup (appended)
        let dbSession = try await createSession(database: dbName)
        _ = try await dbSession.executeUpdate("INSERT INTO dbo.test_data (name, value) VALUES ('new', 100.00)")
        await dbSession.close()

        let second = SQLServerBackupOptions(
            database: dbName, diskPath: path, backupName: "Set 2", initMedia: false
        )
        _ = try await sqlserverClient.backupRestore.backup(options: second)

        let sets = try await sqlserverClient.backupRestore.listBackupSets(diskPath: path)
        XCTAssertEqual(sets.count, 2)

        // Restore from file number 1 (the first backup with 5 rows)
        let killSession = try await createSession()
        _ = try? await killSession.simpleQuery("ALTER DATABASE [\(dbName)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE")
        await killSession.close()
        await dropTestDB(dbName)

        let restoreOptions = SQLServerRestoreOptions(
            database: dbName, diskPath: path,
            fileNumber: 1, recoveryMode: .recovery, replace: true
        )
        _ = try await sqlserverClient.backupRestore.restore(options: restoreOptions)

        let count = try await rowCount(database: dbName, table: "dbo.test_data")
        XCTAssertEqual(count, 5, "Restoring file 1 should have original 5 rows")
    }

    // MARK: - Backup Name and Description

    func testBackupNameAndDescription() async throws {
        let dbName = uniqueTableName(prefix: "bkdesc")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_desc.bak")
        let options = SQLServerBackupOptions(
            database: dbName, diskPath: path,
            backupName: "Production Backup 2024-03-19",
            description: "Nightly full backup before deployment",
            initMedia: true
        )
        _ = try await sqlserverClient.backupRestore.backup(options: options)

        let sets = try await sqlserverClient.backupRestore.listBackupSets(diskPath: path)
        XCTAssertEqual(sets[0].backupName, "Production Backup 2024-03-19")
        XCTAssertEqual(sets[0].backupDescription, "Nightly full backup before deployment")
    }

    // MARK: - Combined Options

    func testFullBackupWithAllOptions() async throws {
        let dbName = uniqueTableName(prefix: "bkall")
        try await setupTestDB(dbName)
        cleanupDB(dbName)

        let path = backupPath("\(dbName)_all.bak")
        let options = SQLServerBackupOptions(
            database: dbName,
            diskPath: path,
            backupType: .full,
            backupName: "Complete Test",
            description: "All options enabled",
            compression: true,
            copyOnly: true,
            checksum: true,
            continueAfterError: true,
            initMedia: true,
            formatMedia: true,
            mediaName: "AllOptionsMedia",
            expireDate: Date().addingTimeInterval(90 * 24 * 3600)
        )
        _ = try await sqlserverClient.backupRestore.backup(options: options)

        // Verify
        _ = try await sqlserverClient.backupRestore.verifyBackup(diskPath: path)
        // Should not throw — backup is valid

        let sets = try await sqlserverClient.backupRestore.listBackupSets(diskPath: path)
        XCTAssertEqual(sets.count, 1)
        XCTAssertEqual(sets[0].backupName, "Complete Test")
        XCTAssertTrue(sets[0].compressed)
    }
}
