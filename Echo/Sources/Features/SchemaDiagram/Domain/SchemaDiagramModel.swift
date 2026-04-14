import Foundation
import SwiftUI
import Observation

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
    let isNullable: Bool

    init(name: String, dataType: String, isPrimaryKey: Bool, isForeignKey: Bool, isNullable: Bool = true) {
        self.id = name
        self.name = name
        self.dataType = dataType
        self.isPrimaryKey = isPrimaryKey
        self.isForeignKey = isForeignKey
        self.isNullable = isNullable
    }
}

struct SchemaDiagramIndex: Identifiable, Hashable {
    let id: String
    let name: String
    let columns: [String]
    let isUnique: Bool

    init(name: String, columns: [String], isUnique: Bool) {
        self.id = name
        self.name = name
        self.columns = columns
        self.isUnique = isUnique
    }
}

enum DiagramLoadSource: Equatable {
    case live(Date)
    case cache(Date)
}

@Observable
final class SchemaDiagramNodeModel: Identifiable {
    let id: String
    @ObservationIgnored let schema: String
    @ObservationIgnored let name: String
    @ObservationIgnored let displayName: String
    @ObservationIgnored let columns: [SchemaDiagramColumn]
    @ObservationIgnored let indexes: [SchemaDiagramIndex]
    @ObservationIgnored let databaseName: String?
    var position: CGPoint

    init(
        schema: String,
        name: String,
        columns: [SchemaDiagramColumn],
        indexes: [SchemaDiagramIndex] = [],
        databaseName: String? = nil,
        position: CGPoint = .zero
    ) {
        self.schema = schema
        self.name = name
        self.displayName = "\(schema).\(name)"
        self.columns = columns
        self.indexes = indexes
        self.databaseName = databaseName
        self.position = position
        self.id = "\(schema).\(name)"
    }
}

struct SchemaDiagramAnnotation: Identifiable {
    let id: UUID
    var text: String
    var position: CGPoint

    init(text: String = "New note", position: CGPoint = .zero) {
        self.id = UUID()
        self.text = text
        self.position = position
    }
}

struct SchemaDiagramContext: Hashable {
    let projectID: UUID?
    let connectionID: UUID
    let connectionSessionID: UUID
    let object: SchemaObjectInfo
    let cacheKey: DiagramCacheKey?
}

@Observable @MainActor
final class SchemaDiagramViewModel {
    var nodes: [SchemaDiagramNodeModel]
    var edges: [SchemaDiagramEdge]
    var annotations: [SchemaDiagramAnnotation]
    var isLoading: Bool
    var statusMessage: String?
    var errorMessage: String?
    var loadSource: DiagramLoadSource = .live(Date())
    @ObservationIgnored let title: String
    @ObservationIgnored let baseNodeID: String
    @ObservationIgnored var layoutIdentifier: String
    @ObservationIgnored var context: SchemaDiagramContext?
    @ObservationIgnored var cachedStructure: DiagramStructureSnapshot?
    @ObservationIgnored var cachedChecksum: String?
    @ObservationIgnored var loadingTask: Task<Void, Never>?

    init(
        nodes: [SchemaDiagramNodeModel],
        edges: [SchemaDiagramEdge],
        annotations: [SchemaDiagramAnnotation] = [],
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
        self.annotations = annotations
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

    // MARK: - Annotations

    func addAnnotation(at position: CGPoint, text: String = "New note") {
        let annotation = SchemaDiagramAnnotation(text: text, position: position)
        annotations.append(annotation)
    }

    func updateAnnotation(id: UUID, text: String) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        annotations[index].text = text
    }

    func moveAnnotation(id: UUID, to position: CGPoint) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        annotations[index].position = position
    }

    func removeAnnotation(id: UUID) {
        annotations.removeAll(where: { $0.id == id })
    }
}
