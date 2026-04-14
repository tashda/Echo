import Testing
@testable import Echo

@Suite("SchemaDiagramModelExporter")
struct SchemaDiagramModelExporterTests {
    @MainActor
    @Test func exportIncludesNodesEdgesAndLayout() {
        let output = SchemaDiagramModelExporter.export(
            title: "Sales Diagram",
            nodes: sampleNodes(),
            edges: sampleEdges(),
            layout: DiagramLayoutSnapshot(
                nodePositions: [
                    .init(nodeID: "public.customers", x: 0, y: 0),
                    .init(nodeID: "public.orders", x: 420, y: 0),
                ]
            )
        )

        #expect(output.contains("\"title\" : \"Sales Diagram\""))
        #expect(output.contains("\"schema\" : \"public\""))
        #expect(output.contains("\"name\" : \"orders\""))
        #expect(output.contains("\"relationshipName\" : \"fk_orders_customer\""))
        #expect(output.contains("\"nodeID\" : \"public.orders\""))
        #expect(output.contains("\"x\" : 420"))
    }

    @MainActor
    @Test func exportIncludesColumnFlags() {
        let output = SchemaDiagramModelExporter.export(
            title: "Flags",
            nodes: sampleNodes(),
            edges: [],
            layout: DiagramLayoutSnapshot(nodePositions: [])
        )

        #expect(output.contains("\"isPrimaryKey\" : true"))
        #expect(output.contains("\"isForeignKey\" : true"))
        #expect(output.contains("\"dataType\" : \"bigint\""))
    }

    @MainActor
    private func sampleNodes() -> [SchemaDiagramNodeModel] {
        [
            SchemaDiagramNodeModel(
                schema: "public",
                name: "customers",
                columns: [
                    SchemaDiagramColumn(name: "id", dataType: "bigint", isPrimaryKey: true, isForeignKey: false),
                ]
            ),
            SchemaDiagramNodeModel(
                schema: "public",
                name: "orders",
                columns: [
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
