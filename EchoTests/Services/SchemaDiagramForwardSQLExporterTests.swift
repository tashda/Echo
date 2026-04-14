import Testing
@testable import Echo

@Suite("SchemaDiagramForwardSQLExporter")
struct SchemaDiagramForwardSQLExporterTests {
    @MainActor
    @Test func exportIncludesCreateTableAndForeignKeyStatements() {
        let output = SchemaDiagramForwardSQLExporter.export(
            title: "Sales Schema",
            nodes: sampleNodes(),
            edges: sampleEdges()
        )

        #expect(output.contains("CREATE TABLE `public`.`customers`"))
        #expect(output.contains("PRIMARY KEY (`id`)"))
        #expect(output.contains("CREATE TABLE `public`.`orders`"))
        #expect(output.contains("ALTER TABLE `public`.`orders`"))
        #expect(output.contains("ADD CONSTRAINT `fk_orders_customer`"))
        #expect(output.contains("REFERENCES `public`.`customers` (`id`);"))
    }

    @MainActor
    @Test func exportEscapesBackticksInIdentifiers() {
        let output = SchemaDiagramForwardSQLExporter.export(
            title: "Quoted",
            nodes: [
                SchemaDiagramNodeModel(
                    schema: "ops",
                    name: "audit`events",
                    columns: [
                        SchemaDiagramColumn(name: "payload`json", dataType: "json", isPrimaryKey: false, isForeignKey: false),
                    ]
                ),
            ],
            edges: []
        )

        #expect(output.contains("CREATE TABLE `ops`.`audit``events`"))
        #expect(output.contains("`payload``json` json"))
    }

    @MainActor
    @Test func exportBuildsCompositePrimaryKeyClause() {
        let output = SchemaDiagramForwardSQLExporter.export(
            title: "Composite",
            nodes: [
                SchemaDiagramNodeModel(
                    schema: "public",
                    name: "order_items",
                    columns: [
                        SchemaDiagramColumn(name: "order_id", dataType: "bigint", isPrimaryKey: true, isForeignKey: true),
                        SchemaDiagramColumn(name: "line_id", dataType: "int", isPrimaryKey: true, isForeignKey: false),
                    ]
                ),
            ],
            edges: []
        )

        #expect(output.contains("PRIMARY KEY (`order_id`, `line_id`)"))
    }

    @MainActor
    private func sampleNodes() -> [SchemaDiagramNodeModel] {
        [
            SchemaDiagramNodeModel(
                schema: "public",
                name: "customers",
                columns: [
                    SchemaDiagramColumn(name: "id", dataType: "bigint", isPrimaryKey: true, isForeignKey: false),
                    SchemaDiagramColumn(name: "name", dataType: "varchar(255)", isPrimaryKey: false, isForeignKey: false),
                ]
            ),
            SchemaDiagramNodeModel(
                schema: "public",
                name: "orders",
                columns: [
                    SchemaDiagramColumn(name: "id", dataType: "bigint", isPrimaryKey: true, isForeignKey: false),
                    SchemaDiagramColumn(name: "customer_id", dataType: "bigint", isPrimaryKey: false, isForeignKey: true),
                ]
            ),
        ]
    }

    private func sampleEdges() -> [SchemaDiagramEdge] {
        [
            SchemaDiagramEdge(
                fromNodeID: "public.orders",
                fromColumn: "customer_id",
                toNodeID: "public.customers",
                toColumn: "id",
                relationshipName: "fk_orders_customer"
            ),
        ]
    }
}
