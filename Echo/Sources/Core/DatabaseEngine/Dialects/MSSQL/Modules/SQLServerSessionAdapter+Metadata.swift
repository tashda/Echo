import Foundation
import SQLServerKit
import OSLog

extension SQLServerSessionAdapter {
    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        let database = self.database
        let tables = try await client.metadata.listTables(database: database, schema: schema)
        return tables.map { table in
            SchemaObjectInfo(
                name: table.name,
                schema: table.schema,
                type: table.isView ? .view : .table,
                comment: table.comment
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

        var stateDesc: String?
        if let meta = try? await client.metadata.databaseState(name: databaseName) {
            stateDesc = meta.stateDescription
        }
        let t2 = CFAbsoluteTimeGetCurrent()
        let totalObjects = schemaInfos.reduce(0) { $0 + $1.objects.count }
        print("[PERF] \(databaseName): total loadDatabaseInfo \(String(format: "%.3f", t2 - t0))s (\(schemaInfos.count) schemas, \(totalObjects) objects)")

        return DatabaseInfo(name: databaseName, schemas: schemaInfos, schemaCount: schemaInfos.count, stateDescription: stateDesc)
    }

    func listExtensions() async throws -> [SchemaObjectInfo] {
        // SQL Server does not have "extensions" in the Postgres sense.
        []
    }

    func listExtensionObjects(extensionName: String) async throws -> [ExtensionObjectInfo] {
        []
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        let effectiveSchema = schemaName ?? "dbo"
        let columns = try await client.metadata.listColumns(
            database: database,
            schema: effectiveSchema,
            table: tableName
        )
        let primaryKeys = try await client.metadata.listPrimaryKeys(
            database: database,
            schema: effectiveSchema,
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

        // Fall back to the simpler OBJECT_DEFINITION() approach
        if let definition = try await client.metadata.objectDefinitionString(
            database: effectiveDatabase,
            schema: schemaName,
            name: objectName
        ) {
            return definition
        }

        throw DatabaseError.queryError("Object definition not found for [\(schemaName)].[\(objectName)]")
    }

    func getTableStructureDetails(schema: String, table: String, database db: String) async throws -> TableStructureDetails {
        try await getTableStructureDetailsImpl(schema: schema, table: table, database: db)
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        try await getTableStructureDetailsImpl(schema: schema, table: table, database: database)
    }

    private func getTableStructureDetailsImpl(schema: String, table: String, database db: String?) async throws -> TableStructureDetails {
        let columns = try await client.metadata.listColumns(database: db, schema: schema, table: table, includeComments: true)
        let primaryKeys = try await client.metadata.listPrimaryKeys(database: db, schema: schema, table: table)
        let indexes = try await client.metadata.listIndexes(database: db, schema: schema, table: table)
        let uniqueConstraints = try await client.metadata.listUniqueConstraints(database: db, schema: schema, table: table)
        let foreignKeys = try await client.metadata.listForeignKeys(database: db, schema: schema, table: table)
        let checkConstraints = (try? await client.constraints.listCheckConstraints(database: db, schema: schema, table: table)) ?? []
        let props = try await client.metadata.tableProperties(database: db, schema: schema, table: table)
        
        let mappedColumns = columns.map { col in
            TableStructureDetails.Column(
                name: col.name,
                dataType: col.typeName,
                isNullable: col.isNullable,
                defaultValue: col.defaultDefinition,
                generatedExpression: col.computedDefinition,
                isIdentity: col.isIdentity,
                identitySeed: col.identitySeed,
                identityIncrement: col.identityIncrement,
                collation: col.collationName,
                comment: col.comment,
                ordinalPosition: col.ordinalPosition
            )
        }
        
        let mappedPK = primaryKeys.first.map { pk in
            TableStructureDetails.PrimaryKey(
                name: pk.name,
                columns: pk.columns.map { $0.column }
            )
        }
        
        let mappedIndexes = indexes.map { idx in
            TableStructureDetails.Index(
                name: idx.name,
                columns: idx.columns.map { col in
                    TableStructureDetails.Index.Column(
                        name: col.column,
                        position: col.ordinal,
                        sortOrder: col.isDescending ? .descending : .ascending,
                        isIncluded: col.isIncluded
                    )
                },
                isUnique: idx.isUnique,
                filterCondition: idx.filterDefinition
            )
        }
        
        let mappedUQs = uniqueConstraints.map { uq in
            TableStructureDetails.UniqueConstraint(
                name: uq.name,
                columns: uq.columns.map { $0.column }
            )
        }
        
        let mappedFKs = foreignKeys.map { fk in
            TableStructureDetails.ForeignKey(
                name: fk.name,
                columns: fk.columns.map { $0.parentColumn },
                referencedSchema: fk.referencedSchema,
                referencedTable: fk.referencedTable,
                referencedColumns: fk.columns.map { $0.referencedColumn },
                onUpdate: fk.updateAction,
                onDelete: fk.deleteAction
            )
        }
        
        let mappedCKs = checkConstraints.map { ck in
            TableStructureDetails.CheckConstraint(
                name: ck.name,
                expression: ck.definition
            )
        }

        let tableProps = TableStructureDetails.TableProperties(
            dataCompression: props.dataCompression,
            filegroup: props.filegroup,
            lockEscalation: props.lockEscalation,
            createdDate: props.createDate?.formatted(),
            modifiedDate: props.modifyDate?.formatted(),
            isSystemObject: props.isSystemObject,
            usesAnsiNulls: props.usesAnsiNulls,
            isReplicated: props.isReplicated,
            textFilegroup: props.textFilegroup,
            filestreamFilegroup: props.filestreamFilegroup,
            isPartitioned: props.isPartitioned,
            partitionScheme: props.partitionScheme,
            partitionColumn: props.partitionColumn,
            partitionCount: props.partitionCount,
            isSystemVersioned: props.isSystemVersioned,
            historyTableSchema: props.historyTableSchema,
            historyTableName: props.historyTableName,
            periodStartColumn: props.periodStartColumn,
            periodEndColumn: props.periodEndColumn,
            isMemoryOptimized: props.isMemoryOptimized,
            memoryOptimizedDurability: props.memoryOptimizedDurability,
            changeTrackingEnabled: props.changeTrackingEnabled,
            trackColumnsUpdated: props.trackColumnsUpdated
        )

        return TableStructureDetails(
            columns: mappedColumns,
            primaryKey: mappedPK,
            indexes: mappedIndexes,
            uniqueConstraints: mappedUQs,
            foreignKeys: mappedFKs,
            dependencies: [], // Dependencies are not currently fetched via nio
            checkConstraints: mappedCKs,
            tableProperties: tableProps
        )
    }

    // MARK: - Helpers

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
}
