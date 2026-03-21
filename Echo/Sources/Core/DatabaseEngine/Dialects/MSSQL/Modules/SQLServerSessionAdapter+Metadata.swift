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
        let structure = try await metadataTimed("loadDatabaseStructure") {
            try await client.metadata.loadDatabaseStructure(database: databaseName, includeComments: false)
        }

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

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String {
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
        default:
            throw DatabaseError.queryError("Unsupported object type")
        }

        guard let result = try await client.metadata.objectDefinition(
            database: database,
            schema: schemaName,
            name: objectName,
            kind: kind
        ), let definition = result.definition else {
            throw DatabaseError.queryError("Object definition not found")
        }

        return definition
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

        // Table properties
        let propsSQL = """
            SELECT
                p.data_compression_desc,
                fg.name AS filegroup_name,
                t.lock_escalation_desc
            FROM sys.tables t
            JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1) AND p.partition_number = 1
            JOIN sys.indexes i ON i.object_id = t.object_id AND i.index_id IN (0, 1)
            JOIN sys.filegroups fg ON fg.data_space_id = i.data_space_id
            WHERE t.object_id = OBJECT_ID('\(schema).\(table)')
            """
        var tableProperties: TableStructureDetails.TableProperties?
        if let propsRows = try? await client.query(propsSQL) {
            for row in propsRows {
                let compression = row.column("data_compression_desc")?.string
                let fg = row.column("filegroup_name")?.string
                let lockEsc = row.column("lock_escalation_desc")?.string
                tableProperties = TableStructureDetails.TableProperties(dataCompression: compression, filegroup: fg, lockEscalation: lockEsc)
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
