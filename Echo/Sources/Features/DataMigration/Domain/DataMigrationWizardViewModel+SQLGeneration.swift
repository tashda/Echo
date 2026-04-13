import Foundation
import Logging

// MARK: - SQL Generation, Migration Execution, and SQL Helpers

extension DataMigrationWizardViewModel {

    // MARK: - SQL Generation

    func generateMigrationSQL() {
        guard let source = sourceSession, let target = targetSession else { return }
        isGenerating = true
        let selectedObjects = sourceObjects.filter { selectedObjectIDs.contains($0.id) }
        let targetType = target.connection.databaseType
        let sourceType = source.connection.databaseType

        Task {
            var sql = "-- Data Migration Script\n"
            sql += "-- Source: \(source.connection.connectionName) (\(sourceType.displayName)) / \(sourceDatabaseName)\n"
            sql += "-- Target: \(target.connection.connectionName) (\(targetType.displayName)) / \(targetDatabaseName)\n"
            sql += "-- Generated: \(Date().formatted())\n\n"

            // Fetch real column metadata from source for accurate DDL
            do {
                let sourceDB = try await source.session.sessionForDatabase(sourceDatabaseName)

                if migrateSchema {
                    sql += "-- === Schema Migration ===\n\n"
                    for obj in selectedObjects {
                        do {
                            let structure = try await sourceDB.getTableStructureDetails(schema: obj.schema, table: obj.name)
                            sql += buildCreateTableSQL(
                                for: obj,
                                structure: structure,
                                targetType: targetType
                            )
                            sql += "\n\n"
                        } catch {
                            sql += "-- Failed to read structure for \(obj.schema).\(obj.name): \(error.localizedDescription)\n\n"
                        }
                    }
                }

                if migrateData {
                    sql += "-- === Data Migration ===\n"
                    sql += "-- Use 'Execute Migration' to transfer data automatically,\n"
                    sql += "-- or run the INSERT statements below against the target.\n\n"
                    for obj in selectedObjects {
                        sql += "-- Data for \(obj.schema).\(obj.name) will be transferred during execution.\n"
                    }
                }
            } catch {
                sql += "-- Error accessing source database: \(error.localizedDescription)\n"
            }

            self.generatedSQL = sql
            self.isGenerating = false
        }
    }

    // MARK: - Execute Migration

    func executeMigration() {
        guard let source = sourceSession, let target = targetSession else { return }
        isMigrating = true
        migrationProgress = 0
        migrationStatus = "Starting migration..."
        migrationLog = []
        migrationError = nil

        let selectedObjects = sourceObjects.filter { selectedObjectIDs.contains($0.id) }
        let targetType = target.connection.databaseType

        Task {
            do {
                let targetDB = try await target.session.sessionForDatabase(targetDatabaseName)
                let sourceDB = try await source.session.sessionForDatabase(sourceDatabaseName)
                let total = Double(selectedObjects.count)

                for (index, obj) in selectedObjects.enumerated() {
                    self.migrationProgress = Double(index) / max(total, 1)
                    self.migrationStatus = "Migrating \(obj.schema).\(obj.name)..."

                    if migrateSchema {
                        do {
                            let structure = try await sourceDB.getTableStructureDetails(schema: obj.schema, table: obj.name)
                            let ddl = buildCreateTableSQL(for: obj, structure: structure, targetType: targetType)

                            if dropTargetIfExists {
                                let dropSQL = dropTableSQL(for: obj, targetType: targetType)
                                _ = try? await targetDB.simpleQuery(dropSQL)
                            }
                            _ = try await targetDB.simpleQuery(ddl)
                            appendLog("Created table \(obj.schema).\(obj.name)")
                        } catch {
                            appendLog("Schema failed for \(obj.schema).\(obj.name): \(error.localizedDescription)")
                            if !continueOnError { throw error }
                        }
                    }

                    if migrateData {
                        do {
                            let sourceQualified = qualifiedName(obj, targetType: source.connection.databaseType)
                            let result = try await sourceDB.simpleQuery("SELECT * FROM \(sourceQualified)")
                            let rowCount = result.rows.count
                            if rowCount > 0 {
                                let insertBatches = buildInsertStatements(
                                    for: obj,
                                    columns: result.columns,
                                    rows: result.rows,
                                    targetType: targetType
                                )
                                for batch in insertBatches {
                                    _ = try await targetDB.simpleQuery(batch)
                                }
                                appendLog("Migrated \(rowCount) rows to \(obj.name)")
                            } else {
                                appendLog("No data in \(obj.name)")
                            }
                        } catch {
                            appendLog("Data transfer failed for \(obj.name): \(error.localizedDescription)")
                            if !continueOnError { throw error }
                        }
                    }
                }

                self.migrationProgress = 1.0
                self.migrationStatus = "Migration completed successfully"
                self.migrationSucceeded = true
            } catch {
                self.migrationError = error.localizedDescription
                self.migrationStatus = "Migration failed"
                logger.error("Migration failed: \(error)")
            }
            self.isMigrating = false
        }
    }

    // MARK: - SQL Helpers

    func qualifiedName(_ obj: MigrationObject, targetType: DatabaseType) -> String {
        switch targetType {
        case .microsoftSQL:
            return "[\(obj.schema)].[\(obj.name)]"
        case .postgresql:
            return "\"\(obj.schema)\".\"\(obj.name)\""
        case .mysql:
            return "`\(obj.name)`"
        case .sqlite:
            return "\"\(obj.name)\""
        }
    }

    func buildCreateTableSQL(
        for obj: MigrationObject,
        structure: TableStructureDetails,
        targetType: DatabaseType
    ) -> String {
        let name = qualifiedName(obj, targetType: targetType)
        let pkColumns = Set(structure.primaryKey?.columns ?? [])
        let columnDefs = structure.columns.map { col in
            let colName = quoteName(col.name, targetType: targetType)
            let typeName = mapDataType(col.dataType, targetType: targetType)
            let nullable = col.isNullable ? "" : " NOT NULL"
            let pk = pkColumns.contains(col.name) ? " PRIMARY KEY" : ""
            return "    \(colName) \(typeName)\(nullable)\(pk)"
        }

        let prefix: String
        switch targetType {
        case .microsoftSQL:
            prefix = "CREATE TABLE \(name)"
        default:
            prefix = "CREATE TABLE IF NOT EXISTS \(name)"
        }

        var sql = "\(prefix) (\n\(columnDefs.joined(separator: ",\n"))\n)"
        if targetType == .microsoftSQL {
            sql += ";\nGO"
        } else {
            sql += ";"
        }
        return sql
    }

    func dropTableSQL(for obj: MigrationObject, targetType: DatabaseType) -> String {
        let name = qualifiedName(obj, targetType: targetType)
        switch targetType {
        case .microsoftSQL:
            return "DROP TABLE IF EXISTS \(name);\nGO"
        default:
            return "DROP TABLE IF EXISTS \(name);"
        }
    }

    func quoteName(_ name: String, targetType: DatabaseType) -> String {
        switch targetType {
        case .microsoftSQL: return "[\(name)]"
        case .mysql: return "`\(name)`"
        default: return "\"\(name)\""
        }
    }

    func mapDataType(_ sourceType: String, targetType: DatabaseType) -> String {
        let normalized = sourceType.uppercased()

        switch targetType {
        case .mysql:
            if normalized.hasPrefix("NVARCHAR") || normalized.hasPrefix("CHARACTER VARYING") { return "VARCHAR(255)" }
            if normalized == "TEXT" || normalized == "NTEXT" { return "TEXT" }
            if normalized == "SERIAL" || normalized == "BIGSERIAL" { return "BIGINT AUTO_INCREMENT" }
            if normalized == "BOOLEAN" || normalized == "BOOL" { return "TINYINT(1)" }
            if normalized.hasPrefix("TIMESTAMP") { return "DATETIME" }
            if normalized == "BYTEA" || normalized == "VARBINARY(MAX)" { return "LONGBLOB" }
            if normalized == "UUID" || normalized == "UNIQUEIDENTIFIER" { return "CHAR(36)" }
            return sourceType
        case .postgresql:
            if normalized.hasPrefix("NVARCHAR") || normalized.hasPrefix("VARCHAR") { return "TEXT" }
            if normalized == "INT" || normalized == "INTEGER" { return "INTEGER" }
            if normalized == "BIGINT" { return "BIGINT" }
            if normalized == "BIT" || normalized == "TINYINT(1)" { return "BOOLEAN" }
            if normalized == "DATETIME" || normalized == "DATETIME2" { return "TIMESTAMP" }
            if normalized == "VARBINARY(MAX)" || normalized == "LONGBLOB" { return "BYTEA" }
            if normalized == "UNIQUEIDENTIFIER" || normalized == "CHAR(36)" { return "UUID" }
            return sourceType
        case .microsoftSQL:
            if normalized == "TEXT" { return "NVARCHAR(MAX)" }
            if normalized == "SERIAL" { return "INT IDENTITY(1,1)" }
            if normalized == "BIGSERIAL" { return "BIGINT IDENTITY(1,1)" }
            if normalized == "BOOLEAN" || normalized == "BOOL" { return "BIT" }
            if normalized == "TIMESTAMP" || normalized.hasPrefix("TIMESTAMP") { return "DATETIME2" }
            if normalized == "BYTEA" || normalized == "LONGBLOB" { return "VARBINARY(MAX)" }
            if normalized == "UUID" { return "UNIQUEIDENTIFIER" }
            return sourceType
        case .sqlite:
            if normalized.contains("INT") { return "INTEGER" }
            if normalized.contains("CHAR") || normalized.contains("TEXT") || normalized.contains("CLOB") { return "TEXT" }
            if normalized.contains("BLOB") || normalized == "BYTEA" { return "BLOB" }
            if normalized.contains("REAL") || normalized.contains("FLOAT") || normalized.contains("DOUBLE") { return "REAL" }
            return sourceType
        }
    }

    func buildInsertStatements(
        for obj: MigrationObject,
        columns: [ColumnInfo],
        rows: [[String?]],
        targetType: DatabaseType
    ) -> [String] {
        guard !rows.isEmpty, !columns.isEmpty else { return [] }

        let tableName = qualifiedName(obj, targetType: targetType)
        let colNames = columns.map { quoteName($0.name, targetType: targetType) }.joined(separator: ", ")

        var batches: [String] = []

        for chunk in stride(from: 0, to: rows.count, by: batchSize) {
            let end = min(chunk + batchSize, rows.count)
            let batchRows = rows[chunk..<end]

            var sql = "INSERT INTO \(tableName) (\(colNames)) VALUES\n"
            let valueLines = batchRows.map { row in
                let values = row.map { escapeValue($0) }.joined(separator: ", ")
                return "(\(values))"
            }
            sql += valueLines.joined(separator: ",\n")
            sql += ";"
            batches.append(sql)
        }

        return batches
    }

    func escapeValue(_ value: String?) -> String {
        guard let value, value != "(null)" else { return "NULL" }
        let escaped = value.replacingOccurrences(of: "'", with: "''")
        return "'\(escaped)'"
    }

    func appendLog(_ message: String) {
        migrationLog.append("[\(Date().formatted(date: .omitted, time: .standard))] \(message)")
    }
}
