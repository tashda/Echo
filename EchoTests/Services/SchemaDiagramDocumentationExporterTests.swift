import Testing
@testable import Echo

@Suite("SchemaDiagramDocumentationExporter")
struct SchemaDiagramDocumentationExporterTests {
    @MainActor
    @Test func markdownIncludesSummaryTablesAndRelationships() {
        let output = SchemaDiagramDocumentationExporter.export(
            title: "Sales Schema",
            nodes: sampleNodes(),
            edges: sampleEdges(),
            format: .markdownDocumentation
        )

        #expect(output.contains("# Sales Schema"))
        #expect(output.contains("## Summary"))
        #expect(output.contains("## public.orders"))
        #expect(output.contains("| id | bigint | Primary Key |"))
        #expect(output.contains("public.orders.`customer_id` -> public.customers.`id`"))
    }

    @MainActor
    @Test func htmlEscapesMarkupInTitlesAndColumns() {
        let output = SchemaDiagramDocumentationExporter.export(
            title: "Ops <Schema>",
            nodes: [
                SchemaDiagramNodeModel(
                    schema: "ops",
                    name: "events",
                    columns: [SchemaDiagramColumn(name: "payload<script>", dataType: "json", isPrimaryKey: false, isForeignKey: false)]
                )
            ],
            edges: [],
            format: .htmlDocumentation
        )

        #expect(output.contains("<title>Ops &lt;Schema&gt;</title>"))
        #expect(output.contains("payload&lt;script&gt;"))
    }

    @MainActor
    @Test func textIncludesRelationshipNamesWhenPresent() {
        let output = SchemaDiagramDocumentationExporter.export(
            title: "Sales",
            nodes: sampleNodes(),
            edges: sampleEdges(),
            format: .textDocumentation
        )

        #expect(output.contains("Relationships"))
        #expect(output.contains("[fk_orders_customer]"))
    }

    @MainActor
    @Test func standardColumnsAreLabeledWhenNotPkOrFk() {
        let output = SchemaDiagramDocumentationExporter.export(
            title: "Public",
            nodes: sampleNodes(),
            edges: [],
            format: .markdownDocumentation
        )

        #expect(output.contains("| name | varchar(255) | Standard |"))
    }

    @MainActor
    private func sampleNodes() -> [SchemaDiagramNodeModel] {
        [
            SchemaDiagramNodeModel(
                schema: "public",
                name: "customers",
                columns: [
                    SchemaDiagramColumn(name: "id", dataType: "bigint", isPrimaryKey: true, isForeignKey: false),
                    SchemaDiagramColumn(name: "name", dataType: "varchar(255)", isPrimaryKey: false, isForeignKey: false)
                ]
            ),
            SchemaDiagramNodeModel(
                schema: "public",
                name: "orders",
                columns: [
                    SchemaDiagramColumn(name: "id", dataType: "bigint", isPrimaryKey: true, isForeignKey: false),
                    SchemaDiagramColumn(name: "customer_id", dataType: "bigint", isPrimaryKey: false, isForeignKey: true)
                ]
            )
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
            )
        ]
    }
}
