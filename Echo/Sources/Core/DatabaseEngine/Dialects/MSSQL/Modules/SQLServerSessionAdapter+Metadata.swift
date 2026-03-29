import Foundation
import SQLServerKit

extension SQLServerSessionAdapter: DatabaseMetadataSession {
    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        let tables = try await client.metadata.listTables(
            database: database,
            schema: schema,
            includeComments: false
        )
        return tables.compactMap { table in
            if table.isSystemObject {
                return nil
            }
            let objectType: SchemaObjectInfo.ObjectType = table.isView ? .view : .table
            return SchemaObjectInfo(
                name: table.name,
                schema: table.schema,
                type: objectType,
                comment: table.comment,
                isSystemVersioned: table.isSystemVersioned ? true : nil,
                isHistoryTable: table.isHistoryTable ? true : nil,
                isMemoryOptimized: table.isMemoryOptimized ? true : nil
            )
        }
    }

    func listDatabases() async throws -> [String] {
        let databases = try await client.metadata.listDatabases()
        return databases.map(\.name)
    }

    /// List databases with state and access information for the sidebar.
    func listDatabasesWithState() async throws -> [(name: String, stateDescription: String?, hasAccess: Bool?)] {
        let databases = try await client.metadata.listDatabases()
        return databases.map { (name: $0.name, stateDescription: $0.stateDescription, hasAccess: $0.hasAccess) }
    }

    func listSchemas() async throws -> [String] {
        let schemas = try await client.metadata.listSchemas(in: database)
        return schemas.map(\.name)
    }

    func loadDatabaseInfo(databaseName: String) async throws -> DatabaseInfo {
        let t0 = CFAbsoluteTimeGetCurrent()
        let structure = try await metadataTimed("loadDatabaseStructure") {
            try await client.metadata.loadDatabaseStructure(database: databaseName, includeComments: false)
        }
        let t1 = CFAbsoluteTimeGetCurrent()
        print("[PERF] \(databaseName): sqlserver-nio loadDatabaseStructure took \(String(format: "%.3f", t1 - t0))s (\(structure.schemas.count) schemas)")

        let schemaInfos = structure.schemas.map { schema -> SchemaInfo in
            var objects: [SchemaObjectInfo] = []
            objects.reserveCapacity(schema.tables.count + schema.views.count + schema.functions.count + schema.procedures.count + schema.triggers.count)

            for table in schema.tables {
                objects.append(makeTableObjectInfo(from: table, type: .table))
            }
            for view in schema.views {
                objects.append(makeTableObjectInfo(from: view, type: .view))
            }
            for routine in schema.functions {
                objects.append(makeRoutineObjectInfo(from: routine))
            }
            for routine in schema.procedures {
                objects.append(makeRoutineObjectInfo(from: routine))
            }
            for trigger in schema.triggers {
                objects.append(makeTriggerObjectInfo(from: trigger))
            }

            return SchemaInfo(name: schema.name, objects: objects)
        }

        // Fetch database state from sys.databases
        var stateDesc: String?
        if let meta = try? await client.metadata.databaseState(name: databaseName) {
            stateDesc = meta.stateDescription
        }
        let t2 = CFAbsoluteTimeGetCurrent()
        let totalObjects = schemaInfos.reduce(0) { $0 + $1.objects.count }
        print("[PERF] \(databaseName): total loadDatabaseInfo \(String(format: "%.3f", t2 - t0))s (\(schemaInfos.count) schemas, \(totalObjects) objects)")

        return DatabaseInfo(name: databaseName, schemas: schemaInfos, schemaCount: schemaInfos.count, stateDescription: stateDesc)
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        let schema = schemaName ?? "dbo"
        let columns = try await client.metadata.listColumns(
            database: database,
            schema: schema,
            table: tableName,
            includeComments: false
        )
        let primaryKeys = try await client.metadata.listPrimaryKeysFromCatalog(
            database: database,
            schema: schema,
            table: tableName
        )
        let primaryKeyColumns = Set(primaryKeys.flatMap { $0.columns.map { $0.column.lowercased() } })

        return columns.map { column in
            ColumnInfo(
                name: column.name,
                dataType: column.typeName,
                isPrimaryKey: primaryKeyColumns.contains(column.name.lowercased()),
                isNullable: column.isNullable,
                maxLength: column.maxLength
            )
        }
    }

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType, database: String? = nil) async throws -> String {
        let effectiveDatabase = database ?? self.database

        let kind: SQLServerMetadataObjectIdentifier.Kind
        switch objectType {
        case .table:
            kind = .table
        case .view:
            kind = .view
        case .procedure:
            kind = .procedure
        case .function:
            kind = .function
        case .trigger:
            kind = .trigger
        default:
            throw DatabaseError.queryError("Unsupported object type")
        }

        // Try the full object definition first (includes preamble and metadata)
        if let result = try await client.metadata.objectDefinition(
            database: effectiveDatabase,
            schema: schemaName,
            name: objectName,
            kind: kind
        ), let definition = result.definition {
            return definition
        }

        // Fall back to the simpler OBJECT_DEFINITION() approach using three-part naming
        let qualifiedName: String
        if let effectiveDatabase {
            qualifiedName = "[\(effectiveDatabase.replacing("]", with: "]]"))].[\(schemaName.replacing("]", with: "]]"))].[\(objectName.replacing("]", with: "]]"))]"
        } else {
            qualifiedName = "[\(schemaName.replacing("]", with: "]]"))].[\(objectName.replacing("]", with: "]]"))]"
        }
        let sql = "SELECT OBJECT_DEFINITION(OBJECT_ID(N'\(qualifiedName)')) AS [definition]"
        let result = try await simpleQuery(sql)
        if let firstRow = result.rows.first, let definition = firstRow.first ?? nil, !definition.isEmpty {
            return definition
        }

        throw DatabaseError.queryError("Object definition not found for [\(schemaName)].[\(objectName)]")
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        let columnMetadata = try await client.metadata.listColumns(
            database: database,
            schema: schema,
            table: table
        )

        let primaryKeyMetadata = try await client.metadata.listPrimaryKeys(
            database: database,
            schema: schema,
            table: table
        )

        let uniqueConstraintMetadata = try await client.metadata.listUniqueConstraints(
            database: database,
            schema: schema,
            table: table
        )

        let foreignKeyMetadata = try await client.metadata.listForeignKeys(
            database: database,
            schema: schema,
            table: table
        )

        let indexMetadata = try await client.metadata.listIndexes(
            database: database,
            schema: schema,
            table: table
        )

        let columns = columnMetadata.map { column in
            TableStructureDetails.Column(
                name: column.name,
                dataType: column.typeName,
                isNullable: column.isNullable,
                defaultValue: column.defaultDefinition,
                generatedExpression: column.computedDefinition,
                isIdentity: column.isIdentity,
                identitySeed: column.identitySeed,
                identityIncrement: column.identityIncrement,
                identityGeneration: column.isIdentity ? "ALWAYS" : nil,
                collation: column.collationName
            )
        }

        let primaryKey = primaryKeyMetadata.first(where: { $0.type == .primaryKey }).map { pk in
            let ordered = pk.columns.sorted { $0.ordinal < $1.ordinal }.map(\.column)
            return TableStructureDetails.PrimaryKey(name: pk.name, columns: ordered)
        }

        let uniqueConstraints = uniqueConstraintMetadata.map { constraint in
            let ordered = constraint.columns.sorted { $0.ordinal < $1.ordinal }.map(\.column)
            return TableStructureDetails.UniqueConstraint(name: constraint.name, columns: ordered)
        }

        let foreignKeys = foreignKeyMetadata.map { fk in
            let ordered = fk.columns.sorted { $0.ordinal < $1.ordinal }
            return TableStructureDetails.ForeignKey(
                name: fk.name,
                columns: ordered.map(\.parentColumn),
                referencedSchema: fk.referencedSchema,
                referencedTable: fk.referencedTable,
                referencedColumns: ordered.map(\.referencedColumn),
                onUpdate: fk.updateAction,
                onDelete: fk.deleteAction
            )
        }

        let excludedIndexNames = Set(uniqueConstraintMetadata.map(\.name)).union(Set(primaryKeyMetadata.map(\.name)))
        let indexes = indexMetadata
            .filter { !excludedIndexNames.contains($0.name) }
            .map { index in
                let columns = index.columns
                    .sorted { $0.ordinal < $1.ordinal }
                    .map { column in
                        TableStructureDetails.Index.Column(
                            name: column.column,
                            position: column.ordinal,
                            sortOrder: column.isDescending ? .descending : .ascending,
                            isIncluded: column.isIncluded
                        )
                    }
                return TableStructureDetails.Index(
                    name: index.name,
                    columns: columns,
                    isUnique: index.isUnique,
                    filterCondition: index.filterDefinition
                )
            }

        // Check constraints
        let checkConstraintSQL = """
            SELECT cc.name, cc.definition
            FROM sys.check_constraints cc
            WHERE cc.parent_object_id = OBJECT_ID('\(schema).\(table)')
            ORDER BY cc.name
            """
        var checkConstraints: [TableStructureDetails.CheckConstraint] = []
        if let results = try? await client.query(checkConstraintSQL) {
            for row in results {
                guard let name = row.column("name")?.string,
                      let definition = row.column("definition")?.string else { continue }
                var expression = definition
                if expression.hasPrefix("(") && expression.hasSuffix(")") {
                    expression = String(expression.dropFirst().dropLast())
                }
                checkConstraints.append(TableStructureDetails.CheckConstraint(name: name, expression: expression))
            }
        }

        // Table properties (including temporal, in-memory OLTP, and SSMS parity fields)
        let propsSQL = """
            SELECT
                p.data_compression_desc,
                fg.name AS filegroup_name,
                t.lock_escalation_desc,
                t.temporal_type,
                hs.name AS history_schema,
                ht.name AS history_table,
                pc_start.name AS period_start_column,
                pc_end.name AS period_end_column,
                t.is_memory_optimized,
                t.durability_desc,
                CONVERT(varchar(23), o.create_date, 121) AS created_date,
                CONVERT(varchar(23), o.modify_date, 121) AS modified_date,
                o.is_ms_shipped,
                t.uses_ansi_nulls,
                t.is_replicated,
                fg_lob.name AS text_filegroup,
                fg_fs.name AS filestream_filegroup,
                CASE WHEN ps.data_space_id IS NOT NULL THEN 1 ELSE 0 END AS is_partitioned,
                ps.name AS partition_scheme,
                pc_part.name AS partition_column,
                (SELECT COUNT(*) FROM sys.partitions sp WHERE sp.object_id = t.object_id AND sp.index_id IN (0, 1)) AS partition_count,
                ct.is_track_columns_updated_on AS track_columns_updated
            FROM sys.tables t
            JOIN sys.objects o ON o.object_id = t.object_id
            JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1) AND p.partition_number = 1
            JOIN sys.indexes i ON i.object_id = t.object_id AND i.index_id IN (0, 1)
            JOIN sys.filegroups fg ON fg.data_space_id = i.data_space_id
            LEFT JOIN sys.tables ht ON ht.object_id = t.history_table_id
            LEFT JOIN sys.schemas hs ON hs.schema_id = ht.schema_id
            LEFT JOIN sys.periods pr ON pr.object_id = t.object_id
            LEFT JOIN sys.columns pc_start ON pc_start.object_id = t.object_id AND pc_start.column_id = pr.start_column_id
            LEFT JOIN sys.columns pc_end ON pc_end.object_id = t.object_id AND pc_end.column_id = pr.end_column_id
            LEFT JOIN sys.filegroups fg_lob ON fg_lob.data_space_id = t.lob_data_space_id
            LEFT JOIN sys.filegroups fg_fs ON fg_fs.data_space_id = t.filestream_data_space_id
            LEFT JOIN sys.partition_schemes ps ON ps.data_space_id = i.data_space_id
            LEFT JOIN sys.index_columns ic_part ON ic_part.object_id = i.object_id AND ic_part.index_id = i.index_id AND ic_part.partition_ordinal = 1
            LEFT JOIN sys.columns pc_part ON pc_part.object_id = t.object_id AND pc_part.column_id = ic_part.column_id
            LEFT JOIN sys.change_tracking_tables ct ON ct.object_id = t.object_id
            WHERE t.object_id = OBJECT_ID('\(schema).\(table)')
            """
        var tableProperties: TableStructureDetails.TableProperties?
        if let propsRows = try? await client.query(propsSQL) {
            for row in propsRows {
                let compression = row.column("data_compression_desc")?.string
                let fg = row.column("filegroup_name")?.string
                let lockEsc = row.column("lock_escalation_desc")?.string
                let temporalType = row.column("temporal_type")?.int ?? 0
                let isMemOpt = (row.column("is_memory_optimized")?.int ?? 0) != 0
                let isPartitioned = (row.column("is_partitioned")?.int ?? 0) != 0
                let ctTrackCols = row.column("track_columns_updated")?.int
                tableProperties = TableStructureDetails.TableProperties(
                    dataCompression: compression, filegroup: fg, lockEscalation: lockEsc,
                    createdDate: row.column("created_date")?.string,
                    modifiedDate: row.column("modified_date")?.string,
                    isSystemObject: (row.column("is_ms_shipped")?.int ?? 0) != 0 ? true : nil,
                    usesAnsiNulls: (row.column("uses_ansi_nulls")?.int ?? 0) != 0 ? true : false,
                    isReplicated: (row.column("is_replicated")?.int ?? 0) != 0 ? true : nil,
                    textFilegroup: row.column("text_filegroup")?.string,
                    filestreamFilegroup: row.column("filestream_filegroup")?.string,
                    isPartitioned: isPartitioned ? true : nil,
                    partitionScheme: isPartitioned ? row.column("partition_scheme")?.string : nil,
                    partitionColumn: isPartitioned ? row.column("partition_column")?.string : nil,
                    partitionCount: isPartitioned ? row.column("partition_count")?.int : nil,
                    isSystemVersioned: temporalType == 2 ? true : nil,
                    historyTableSchema: row.column("history_schema")?.string,
                    historyTableName: row.column("history_table")?.string,
                    periodStartColumn: row.column("period_start_column")?.string,
                    periodEndColumn: row.column("period_end_column")?.string,
                    isMemoryOptimized: isMemOpt ? true : nil,
                    memoryOptimizedDurability: isMemOpt ? row.column("durability_desc")?.string : nil,
                    changeTrackingEnabled: ctTrackCols != nil ? true : nil,
                    trackColumnsUpdated: ctTrackCols != nil ? (ctTrackCols != 0) : nil
                )
            }
        }

        return TableStructureDetails(
            columns: columns,
            primaryKey: primaryKey,
            indexes: indexes,
            uniqueConstraints: uniqueConstraints,
            foreignKeys: foreignKeys,
            dependencies: [],
            checkConstraints: checkConstraints,
            tableProperties: tableProperties
        )
    }

    func loadSchemaInfo(
        _ schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> SchemaInfo {
        let schema = try await client.metadata.loadSchemaStructure(
            database: database,
            schema: schemaName,
            includeComments: false
        )

        var objects: [SchemaObjectInfo] = []
        objects.reserveCapacity(schema.tables.count + schema.views.count + schema.functions.count + schema.procedures.count + schema.triggers.count)

        for table in schema.tables {
            objects.append(makeTableObjectInfo(from: table, type: .table))
        }
        for view in schema.views {
            objects.append(makeTableObjectInfo(from: view, type: .view))
        }
        for routine in schema.functions {
            objects.append(makeRoutineObjectInfo(from: routine))
        }
        for routine in schema.procedures {
            objects.append(makeRoutineObjectInfo(from: routine))
        }
        for trigger in schema.triggers {
            objects.append(makeTriggerObjectInfo(from: trigger))
        }

        for synonym in schema.synonyms {
            objects.append(SchemaObjectInfo(name: synonym.name, schema: synonym.schema, type: .synonym, comment: synonym.comment))
        }

        if let progress {
            let total = objects.count
            if total > 0 {
                var current = 0
                for object in objects {
                    current += 1
                    await progress(object.type, current, total)
                }
            }
        }

        return SchemaInfo(name: schemaName, objects: objects)
    }

    private func makeTableObjectInfo(from table: SQLServerTableStructure, type: SchemaObjectInfo.ObjectType) -> SchemaObjectInfo {
        let primaryKeyColumns = Set(table.primaryKey?.columns.map { $0.column.lowercased() } ?? [])
        let columns = table.columns.map { column in
            ColumnInfo(
                name: column.name,
                dataType: column.typeName,
                isPrimaryKey: primaryKeyColumns.contains(column.name.lowercased()),
                isNullable: column.isNullable,
                maxLength: column.maxLength
            )
        }
        return SchemaObjectInfo(
            name: table.table.name,
            schema: table.table.schema,
            type: type,
            columns: columns,
            comment: table.table.comment
        )
    }

    private func makeRoutineObjectInfo(from routine: RoutineMetadata) -> SchemaObjectInfo {
        let type: SchemaObjectInfo.ObjectType = routine.type == .procedure ? .procedure : .function
        return SchemaObjectInfo(
            name: routine.name,
            schema: routine.schema,
            type: type,
            comment: routine.comment
        )
    }

    private func makeTriggerObjectInfo(from trigger: TriggerMetadata) -> SchemaObjectInfo {
        SchemaObjectInfo(
            name: trigger.name,
            schema: trigger.schema,
            type: .trigger,
            columns: [],
            triggerAction: trigger.isInsteadOf ? "INSTEAD OF" : "AFTER",
            triggerTable: trigger.table,
            comment: trigger.comment
        )
    }

    func listAvailableExtensions() async throws -> [AvailableExtensionInfo] {
        []
    }

    func installExtension(name: String, schema: String?, version: String?, cascade: Bool) async throws {
        throw DatabaseError.queryError("Extensions are not supported for SQL Server")
    }
}
