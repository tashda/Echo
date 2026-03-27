import Foundation
import SQLServerKit

extension MSSQLDedicatedQuerySession {
    func isSuperuser() async throws -> Bool {
        try await metadataSession.isSuperuser()
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        try await metadataSession.listTablesAndViews(schema: schema)
    }

    func listDatabases() async throws -> [String] {
        try await metadataSession.listDatabases()
    }

    func listSchemas() async throws -> [String] {
        try await metadataSession.listSchemas()
    }

    func listExtensions() async throws -> [SchemaObjectInfo] {
        try await metadataSession.listExtensions()
    }

    func listExtensionObjects(extensionName: String) async throws -> [ExtensionObjectInfo] {
        try await metadataSession.listExtensionObjects(extensionName: extensionName)
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        try await metadataSession.getTableSchema(tableName, schemaName: schemaName)
    }

    func getObjectDefinition(
        objectName: String,
        schemaName: String,
        objectType: SchemaObjectInfo.ObjectType,
        database: String? = nil
    ) async throws -> String {
        try await metadataSession.getObjectDefinition(
            objectName: objectName,
            schemaName: schemaName,
            objectType: objectType,
            database: database
        )
    }

    func renameTable(schema: String?, oldName: String, newName: String) async throws {
        try await metadataSession.renameTable(schema: schema, oldName: oldName, newName: newName)
    }

    func dropTable(schema: String?, name: String, ifExists: Bool) async throws {
        try await metadataSession.dropTable(schema: schema, name: name, ifExists: ifExists)
    }

    func truncateTable(schema: String?, name: String) async throws {
        try await metadataSession.truncateTable(schema: schema, name: name)
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        try await metadataSession.getTableStructureDetails(schema: schema, table: table)
    }

    func dropIndex(schema: String, name: String) async throws {
        try await metadataSession.dropIndex(schema: schema, name: name)
    }

    func rebuildIndex(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult {
        try await metadataSession.rebuildIndex(schema: schema, table: table, index: index)
    }

    func rebuildIndexes(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        try await metadataSession.rebuildIndexes(schema: schema, table: table)
    }

    func reorganizeIndex(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult {
        try await metadataSession.reorganizeIndex(schema: schema, table: table, index: index)
    }

    func reorganizeIndexes(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        try await metadataSession.reorganizeIndexes(schema: schema, table: table)
    }

    func vacuumTable(schema: String, table: String, full: Bool, analyze: Bool) async throws {
        try await metadataSession.vacuumTable(schema: schema, table: table, full: full, analyze: analyze)
    }

    func analyzeTable(schema: String, table: String) async throws {
        try await metadataSession.analyzeTable(schema: schema, table: table)
    }

    func reindexTable(schema: String, table: String) async throws {
        try await metadataSession.reindexTable(schema: schema, table: table)
    }

    func updateTableStatistics(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        try await metadataSession.updateTableStatistics(schema: schema, table: table)
    }

    func updateIndexStatistics(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult {
        try await metadataSession.updateIndexStatistics(schema: schema, table: table, index: index)
    }

    func listTableStats() async throws -> [SQLServerTableStat] {
        try await metadataSession.listTableStats()
    }

    func checkTable(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        try await metadataSession.checkTable(schema: schema, table: table)
    }

    func rebuildTable(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        try await metadataSession.rebuildTable(schema: schema, table: table)
    }

    func listFragmentedIndexes() async throws -> [SQLServerIndexFragmentation] {
        try await metadataSession.listFragmentedIndexes()
    }

    func getDatabaseHealth() async throws -> SQLServerDatabaseHealth {
        try await metadataSession.getDatabaseHealth()
    }

    func getBackupHistory(limit: Int) async throws -> [SQLServerBackupHistoryEntry] {
        try await metadataSession.getBackupHistory(limit: limit)
    }

    func checkDatabaseIntegrity() async throws -> DatabaseMaintenanceResult {
        try await metadataSession.checkDatabaseIntegrity()
    }

    func shrinkDatabase() async throws -> DatabaseMaintenanceResult {
        try await metadataSession.shrinkDatabase()
    }

    func shrinkDatabase(targetPercent: Int, truncateOnly: Bool) async throws -> DatabaseMaintenanceResult {
        try await metadataSession.shrinkDatabase(targetPercent: targetPercent, truncateOnly: truncateOnly)
    }

    func shrinkFile(fileName: String, targetSizeMB: Int) async throws -> DatabaseMaintenanceResult {
        try await metadataSession.shrinkFile(fileName: fileName, targetSizeMB: targetSizeMB)
    }

    func listDatabaseFiles() async throws -> [SQLServerDatabaseFile] {
        try await metadataSession.listDatabaseFiles()
    }

    func detachDatabase(name: String, skipChecks: Bool) async throws {
        try await metadataSession.detachDatabase(name: name, skipChecks: skipChecks)
    }

    func attachDatabase(name: String, files: [String]) async throws {
        try await metadataSession.attachDatabase(name: name, files: files)
    }

    func listDatabaseSnapshots() async throws -> [SQLServerDatabaseSnapshot] {
        try await metadataSession.listDatabaseSnapshots()
    }

    func createDatabaseSnapshot(name: String, sourceDatabase: String) async throws {
        try await metadataSession.createDatabaseSnapshot(name: name, sourceDatabase: sourceDatabase)
    }

    func deleteDatabaseSnapshot(name: String) async throws {
        try await metadataSession.deleteDatabaseSnapshot(name: name)
    }

    func revertToSnapshot(snapshotName: String) async throws {
        try await metadataSession.revertToSnapshot(snapshotName: snapshotName)
    }

    func sessionForDatabase(_ database: String) async throws -> DatabaseSession {
        let connection = try await readyConnection()
        try await connection.changeDatabase(database)
        return self
    }

    func currentDatabaseName() async throws -> String? {
        let connection = try await readyConnection()
        return connection.currentDatabase
    }

    func makeActivityMonitor() throws -> any DatabaseActivityMonitoring {
        try metadataSession.makeActivityMonitor()
    }
}
