import Foundation
import MySQLKit

extension MySQLSession {
    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        async let structureResult = client.metadata.tableStructure(for: table, schema: schema)
        async let tableOptionsResult = client.metadata.tableOptions(for: table, schema: schema)
        let structure = try await structureResult
        let tableOptions = try await tableOptionsResult

        let columns = structure.columns.map { column -> TableStructureDetails.Column in
            TableStructureDetails.Column(
                name: column.name,
                dataType: column.fullDataType,
                isNullable: column.isNullable,
                defaultValue: column.defaultValue,
                generatedExpression: column.generationExpression,
                isIdentity: column.isAutoIncrement,
                identitySeed: column.isAutoIncrement ? 1 : nil,
                identityIncrement: column.isAutoIncrement ? 1 : nil,
                identityGeneration: column.isAutoIncrement ? "AUTO_INCREMENT" : nil,
                collation: column.collation
            )
        }

        let primaryKey = structure.primaryKey.map {
            TableStructureDetails.PrimaryKey(name: $0.name, columns: $0.columns)
        }
        let indexes = structure.indexes.map {
            TableStructureDetails.Index(
                name: $0.name,
                columns: $0.columns.map {
                    TableStructureDetails.Index.Column(
                        name: $0.name,
                        position: $0.position,
                        sortOrder: $0.sortOrder == .descending ? .descending : .ascending
                    )
                },
                isUnique: $0.isUnique,
                filterCondition: nil,
                indexType: $0.indexType?.lowercased()
            )
        }
        let foreignKeys = structure.foreignKeys.map {
            TableStructureDetails.ForeignKey(
                name: $0.name,
                columns: $0.columns,
                referencedSchema: $0.referencedSchema,
                referencedTable: $0.referencedTable,
                referencedColumns: $0.referencedColumns,
                onUpdate: $0.onUpdate,
                onDelete: $0.onDelete
            )
        }
        let dependencies = structure.dependencies.map {
            TableStructureDetails.Dependency(
                name: $0.name,
                baseColumns: $0.baseColumns,
                referencedTable: $0.referencedTable,
                referencedColumns: $0.referencedColumns,
                onUpdate: $0.onUpdate,
                onDelete: $0.onDelete
            )
        }
        let tableProperties = tableOptions.map {
            TableStructureDetails.TableProperties(
                storageEngine: $0.engine,
                characterSet: $0.characterSet,
                collation: $0.collation,
                autoIncrementValue: $0.autoIncrement,
                rowFormat: $0.rowFormat,
                tableComment: $0.comment,
                estimatedRowCount: $0.estimatedRowCount,
                dataLengthBytes: $0.dataLength,
                indexLengthBytes: $0.indexLength
            )
        }

        return TableStructureDetails(
            columns: columns,
            primaryKey: primaryKey,
            indexes: indexes,
            uniqueConstraints: [],
            foreignKeys: foreignKeys,
            dependencies: dependencies,
            tableProperties: tableProperties
        )
    }
}
