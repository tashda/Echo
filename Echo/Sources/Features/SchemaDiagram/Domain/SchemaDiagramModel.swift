import Foundation
import SwiftUI
import Combine

struct SchemaDiagramEdge: Identifiable, Hashable {
    let fromNodeID: String
    let fromColumn: String
    let toNodeID: String
    let toColumn: String
    let relationshipName: String?

    var id: String {
        [
            fromNodeID,
            fromColumn,
            toNodeID,
            toColumn,
            relationshipName ?? ""
        ].joined(separator: "|")
    }
}

struct SchemaDiagramColumn: Identifiable, Hashable {
    let id: String
    let name: String
    let dataType: String
    let isPrimaryKey: Bool
    let isForeignKey: Bool

    init(name: String, dataType: String, isPrimaryKey: Bool, isForeignKey: Bool) {
        self.id = name
        self.name = name
        self.dataType = dataType
        self.isPrimaryKey = isPrimaryKey
        self.isForeignKey = isForeignKey
    }
}

enum DiagramLoadSource: Equatable {
    case live(Date)
    case cache(Date)
}

final class SchemaDiagramNodeModel: ObservableObject, Identifiable {
    let id: String
    let schema: String
    let name: String
    let displayName: String
    let columns: [SchemaDiagramColumn]
    @Published var position: CGPoint

    init(
        schema: String,
        name: String,
        columns: [SchemaDiagramColumn],
        position: CGPoint = .zero
    ) {
        self.schema = schema
        self.name = name
        self.displayName = "\(schema).\(name)"
        self.columns = columns
        self.position = position
        self.id = "\(schema).\(name)"
    }
}

struct SchemaDiagramContext: Hashable {
    let projectID: UUID?
    let connectionID: UUID
    let connectionSessionID: UUID
    let object: SchemaObjectInfo
    let cacheKey: DiagramCacheKey?
}

@MainActor
final class SchemaDiagramViewModel: ObservableObject {
    @Published var nodes: [SchemaDiagramNodeModel]
    @Published var edges: [SchemaDiagramEdge]
    @Published var isLoading: Bool
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var loadSource: DiagramLoadSource = .live(Date())
    let title: String
    let baseNodeID: String
    var layoutIdentifier: String
    var context: SchemaDiagramContext?
    var cachedStructure: DiagramStructureSnapshot?
    var cachedChecksum: String?

    init(
        nodes: [SchemaDiagramNodeModel],
        edges: [SchemaDiagramEdge],
        baseNodeID: String,
        title: String,
        isLoading: Bool = false,
        statusMessage: String? = nil,
        errorMessage: String? = nil,
        layoutIdentifier: String? = nil,
        context: SchemaDiagramContext? = nil,
        cachedStructure: DiagramStructureSnapshot? = nil,
        cachedChecksum: String? = nil,
        loadSource: DiagramLoadSource = .live(Date())
    ) {
        self.nodes = nodes
        self.edges = edges
        self.baseNodeID = baseNodeID
        self.title = title
        self.isLoading = isLoading
        self.statusMessage = statusMessage
        self.errorMessage = errorMessage
        self.layoutIdentifier = layoutIdentifier ?? "primary"
        self.context = context
        self.cachedStructure = cachedStructure
        self.cachedChecksum = cachedChecksum
        self.loadSource = loadSource
    }

    func node(for id: String) -> SchemaDiagramNodeModel? {
        nodes.first(where: { $0.id == id })
    }

    func estimatedMemoryUsageBytes() -> Int {
        let baseOverhead = 40 * 1024
        let nodeBytes = nodes.reduce(0) { partial, node in
            let nameBytes = node.displayName.utf8.count * 2
            let columnBytes = node.columns.reduce(0) { sum, column in
                sum + column.name.utf8.count * 2 + column.dataType.utf8.count * 2 + 96
            }
            return partial + 256 + nameBytes + columnBytes
        }
        let edgeBytes = edges.reduce(0) { partial, edge in
            let fromBytes = edge.fromNodeID.utf8.count * 2
            let toBytes = edge.toNodeID.utf8.count * 2
            let nameBytes = (edge.relationshipName?.utf8.count ?? 0) * 2
            return partial + fromBytes + toBytes + nameBytes + 160
        }
        return baseOverhead + nodeBytes + edgeBytes
    }

    func layoutSnapshot() -> DiagramLayoutSnapshot {
        let positions = nodes.map { node in
            DiagramLayoutSnapshot.NodePosition(
                nodeID: node.id,
                x: Double(node.position.x),
                y: Double(node.position.y)
            )
        }
        return DiagramLayoutSnapshot(layoutID: layoutIdentifier, nodePositions: positions)
    }
}
