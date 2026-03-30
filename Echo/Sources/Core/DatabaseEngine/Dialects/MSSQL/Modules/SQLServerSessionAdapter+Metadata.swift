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

    func listSchemas() async throws -> [String] {
        let schemas = try await client.metadata.listSchemas(in: database)
        return schemas.map(\.name)
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
        let checkConstraints = try await client.metadata.listCheckConstraints(database: db, schema: schema, table: table)
        let props = try await client.metadata.tableProperties(database: db, schema: schema, table: table)
        
        let pkColumns = Set(primaryKeys.flatMap { $0.columns.map { $0.column } })
        
        let mappedColumns = columns.map { col in
            TableStructureDetails.Column(
                name: col.name,
                dataType: col.typeName,
                isNullable: col.isNullable,
                defaultValue: col.defaultValue,
                generatedExpression: col.generatedExpression,
                isIdentity: col.isIdentity,
                identitySeed: col.identitySeed,
                identityIncrement: col.identityIncrement,
                collation: col.collation,
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
}
