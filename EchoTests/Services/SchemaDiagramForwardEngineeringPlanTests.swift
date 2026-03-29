import Foundation
import Testing
@testable import Echo

@Suite("SchemaDiagramForwardEngineeringPlan")
struct SchemaDiagramForwardEngineeringPlanTests {
    @MainActor
    @Test func targetDatabaseUsesSchemaNameForMySQL() {
        let database = SchemaDiagramForwardEngineeringPlan.targetDatabase(
            for: .mysql,
            context: context(schema: "sakila"),
            fallbackDatabase: "mysql"
        )

        #expect(database == "sakila")
    }

    @MainActor
    @Test func targetDatabaseFallsBackToConnectionDatabaseForPostgres() {
        let database = SchemaDiagramForwardEngineeringPlan.targetDatabase(
            for: .postgresql,
            context: context(schema: "public"),
            fallbackDatabase: "appdb"
        )

        #expect(database == "appdb")
    }

    @MainActor
    @Test func targetDatabaseOmitsDatabaseForMSSQL() {
        let database = SchemaDiagramForwardEngineeringPlan.targetDatabase(
            for: .microsoftSQL,
            context: context(schema: "dbo"),
            fallbackDatabase: "master"
        )

        #expect(database == nil)
    }

    @MainActor
    @Test func sqlUsesForwardEngineeringExporter() {
        let sql = SchemaDiagramForwardEngineeringPlan.sql(
            title: "Sales Schema",
            nodes: [
                SchemaDiagramNodeModel(
                    schema: "sales",
                    name: "customers",
                    columns: [
                        SchemaDiagramColumn(name: "id", dataType: "bigint", isPrimaryKey: true, isForeignKey: false),
                    ]
                ),
            ],
            edges: []
        )

        #expect(sql.contains("CREATE TABLE `sales`.`customers`"))
        #expect(sql.contains("PRIMARY KEY (`id`)"))
    }

    @MainActor
    private func context(schema: String) -> SchemaDiagramContext {
        SchemaDiagramContext(
            projectID: UUID(),
            connectionID: UUID(),
            connectionSessionID: UUID(),
            object: SchemaObjectInfo(
                name: "orders",
                schema: schema,
                type: .table
            ),
            cacheKey: nil
        )
    }
}
