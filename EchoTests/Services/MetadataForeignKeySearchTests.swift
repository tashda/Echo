import Foundation
import Testing
@testable import Echo

@Suite("MetadataSearchEngine Foreign Key Search")
struct MetadataForeignKeySearchTests {

    @Test func searchFindsForeignKeyByConstraintName() async {
        let snapshot = makeSnapshot(tables: [
            makeTable("orders", columns: [
                ColumnInfo(name: "id", dataType: "INTEGER", isPrimaryKey: true),
                ColumnInfo(
                    name: "customer_id", dataType: "INTEGER",
                    foreignKey: ColumnInfo.ForeignKeyReference(
                        constraintName: "fk_orders_0",
                        referencedSchema: "main",
                        referencedTable: "customers",
                        referencedColumn: "id"
                    )
                ),
            ])
        ])

        let results = await MetadataSearchEngine.search(
            query: "fk_orders",
            scope: .allServers,
            snapshots: [snapshot],
            categories: [.foreignKeys]
        )

        #expect(results.count == 1)
        #expect(results.first?.title == "fk_orders_0")
        #expect(results.first?.category == .foreignKeys)
    }

    @Test func searchFindsForeignKeyByReferencedTable() async {
        let snapshot = makeSnapshot(tables: [
            makeTable("orders", columns: [
                ColumnInfo(
                    name: "customer_id", dataType: "INTEGER",
                    foreignKey: ColumnInfo.ForeignKeyReference(
                        constraintName: "fk_orders_0",
                        referencedSchema: "main",
                        referencedTable: "customers",
                        referencedColumn: "id"
                    )
                ),
            ])
        ])

        let results = await MetadataSearchEngine.search(
            query: "customers",
            scope: .allServers,
            snapshots: [snapshot],
            categories: [.foreignKeys]
        )

        #expect(results.count == 1)
        #expect(results.first?.metadata == "→ customers.id")
    }

    @Test func searchFindsForeignKeyByColumnName() async {
        let snapshot = makeSnapshot(tables: [
            makeTable("orders", columns: [
                ColumnInfo(
                    name: "customer_id", dataType: "INTEGER",
                    foreignKey: ColumnInfo.ForeignKeyReference(
                        constraintName: "fk_orders_0",
                        referencedSchema: "main",
                        referencedTable: "customers",
                        referencedColumn: "id"
                    )
                ),
            ])
        ])

        let results = await MetadataSearchEngine.search(
            query: "customer_id",
            scope: .allServers,
            snapshots: [snapshot],
            categories: [.foreignKeys]
        )

        #expect(results.count == 1)
    }

    @Test func searchReturnsEmptyWhenNoMatch() async {
        let snapshot = makeSnapshot(tables: [
            makeTable("orders", columns: [
                ColumnInfo(
                    name: "customer_id", dataType: "INTEGER",
                    foreignKey: ColumnInfo.ForeignKeyReference(
                        constraintName: "fk_orders_0",
                        referencedSchema: "main",
                        referencedTable: "customers",
                        referencedColumn: "id"
                    )
                ),
            ])
        ])

        let results = await MetadataSearchEngine.search(
            query: "nonexistent",
            scope: .allServers,
            snapshots: [snapshot],
            categories: [.foreignKeys]
        )

        #expect(results.isEmpty)
    }

    @Test func searchSkipsColumnsWithoutForeignKeys() async {
        let snapshot = makeSnapshot(tables: [
            makeTable("orders", columns: [
                ColumnInfo(name: "id", dataType: "INTEGER", isPrimaryKey: true),
                ColumnInfo(name: "total", dataType: "REAL"),
            ])
        ])

        let results = await MetadataSearchEngine.search(
            query: "id",
            scope: .allServers,
            snapshots: [snapshot],
            categories: [.foreignKeys]
        )

        #expect(results.isEmpty)
    }

    // MARK: - Helpers

    private func makeSnapshot(tables: [SchemaObjectInfo]) -> MetadataSearchEngine.SessionSnapshot {
        let schema = SchemaInfo(name: "main", objects: tables)
        let database = DatabaseInfo(name: "test.db", schemas: [schema], schemaCount: 1)
        let structure = DatabaseStructure(serverVersion: "SQLite 3.45", databases: [database])
        return MetadataSearchEngine.SessionSnapshot(
            sessionID: UUID(),
            serverName: "test.db",
            databaseType: .sqlite,
            structure: structure
        )
    }

    private func makeTable(_ name: String, columns: [ColumnInfo]) -> SchemaObjectInfo {
        SchemaObjectInfo(name: name, schema: "main", type: .table, columns: columns)
    }
}
