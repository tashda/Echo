import Foundation
import MySQLKit

extension MySQLSession {
    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        let structure = try await client.metadata.tableStructure(for: table, schema: schema)

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

        return TableStructureDetails(
            columns: columns,
            primaryKey: primaryKey,
            indexes: indexes,
            uniqueConstraints: [],
            foreignKeys: foreignKeys,
            dependencies: dependencies
        )
    }
}
