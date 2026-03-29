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
        var checkConstraints: [TableStructureDetails.CheckConstraint] = []
        if let nioConstraints = try? await client.constraints.listCheckConstraints(database: database, schema: schema, table: table) {
            checkConstraints = nioConstraints.map { constraint in
                var expression = constraint.definition
                if expression.hasPrefix("(") && expression.hasSuffix(")") {
                    expression = String(expression.dropFirst().dropLast())
                }
                return TableStructureDetails.CheckConstraint(name: constraint.name, expression: expression)
            }
        }

        // Table properties (including temporal, in-memory OLTP, and SSMS parity fields)
        var tableProperties: TableStructureDetails.TableProperties?
        if let props = try? await client.metadata.tableProperties(database: database, schema: schema, table: table) {
            let dateFormatter = { () -> DateFormatter in
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
                return df
            }()
            tableProperties = TableStructureDetails.TableProperties(
                dataCompression: props.dataCompression,
                filegroup: props.filegroup,
                lockEscalation: props.lockEscalation,
                createdDate: props.createDate.map { dateFormatter.string(from: $0) },
                modifiedDate: props.modifyDate.map { dateFormatter.string(from: $0) },
                isSystemObject: props.isSystemObject,
                usesAnsiNulls: props.usesAnsiNulls ?? false,
                isReplicated: props.isReplicated,
                textFilegroup: props.textFilegroup,
                filestreamFilegroup: props.filestreamFilegroup,
                isPartitioned: props.isPartitioned,
                partitionScheme: props.isPartitioned == true ? props.partitionScheme : nil,
                partitionColumn: props.isPartitioned == true ? props.partitionColumn : nil,
                partitionCount: props.isPartitioned == true ? props.partitionCount : nil,
                isSystemVersioned: props.isSystemVersioned,
                historyTableSchema: props.historyTableSchema,
                historyTableName: props.historyTableName,
                periodStartColumn: props.periodStartColumn,
                periodEndColumn: props.periodEndColumn,
                isMemoryOptimized: props.isMemoryOptimized,
                memoryOptimizedDurability: props.isMemoryOptimized == true ? props.memoryOptimizedDurability : nil,
                changeTrackingEnabled: props.changeTrackingEnabled,
                trackColumnsUpdated: props.trackColumnsUpdated
            )
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
