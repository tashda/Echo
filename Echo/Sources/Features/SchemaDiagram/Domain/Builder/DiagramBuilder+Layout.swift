import Foundation
import SwiftUI

extension DiagramBuilder {
    func makeDiagramViewModel(
        title: String,
        baseKey: DiagramTableKey,
        tableDetails: [DiagramTableKey: TableStructureDetails],
        layoutSnapshot: DiagramLayoutSnapshot?,
        structureSnapshot: DiagramStructureSnapshot? = nil,
        checksum: String? = nil,
        loadSource: DiagramLoadSource = .live(Date()),
        inboundKeys: Set<DiagramTableKey> = [],
        outboundKeys: Set<DiagramTableKey> = [],
        databaseName: String? = nil
    ) -> SchemaDiagramViewModel {
        func buildColumns(for details: TableStructureDetails) -> [SchemaDiagramColumn] {
            let primaryKeys = Set(details.primaryKey?.columns.map { $0.lowercased() } ?? [])
            let foreignKeys = Set(details.foreignKeys.flatMap { $0.columns.map { $0.lowercased() } })
            return details.columns.map { column in
                SchemaDiagramColumn(
                    name: column.name,
                    dataType: column.dataType,
                    isPrimaryKey: primaryKeys.contains(column.name.lowercased()),
                    isForeignKey: foreignKeys.contains(column.name.lowercased()),
                    isNullable: column.isNullable
                )
            }
        }

        func buildIndexes(for details: TableStructureDetails) -> [SchemaDiagramIndex] {
            details.indexes.map { index in
                SchemaDiagramIndex(
                    name: index.name,
                    columns: index.columns.sorted(by: { $0.position < $1.position }).map(\.name),
                    isUnique: index.isUnique
                )
            }
        }

        var edges: [SchemaDiagramEdge] = []
        func appendForeignKeyEdges(from tableKey: DiagramTableKey, details: TableStructureDetails) {
            for fk in details.foreignKeys {
                let targetSchema = fk.referencedSchema.isEmpty ? tableKey.schema : fk.referencedSchema
                let targetKey = DiagramTableKey(schema: targetSchema, name: fk.referencedTable)
                for pair in zip(fk.columns, fk.referencedColumns) {
                    edges.append(
                        SchemaDiagramEdge(
                            fromNodeID: tableKey.identifier,
                            fromColumn: pair.0,
                            toNodeID: targetKey.identifier,
                            toColumn: pair.1,
                            relationshipName: fk.name
                        )
                    )
                }
            }
        }

        let spacingX: CGFloat = 420
        let spacingY: CGFloat = 320
        let baseIdentifier = baseKey.identifier
        let inboundIdentifiers = Set(inboundKeys.map(\.identifier))
        let outboundIdentifiers = Set(outboundKeys.map(\.identifier))
        let overlapIdentifiers = inboundIdentifiers.intersection(outboundIdentifiers)
        let inboundOnlyIdentifiers = inboundIdentifiers.subtracting(overlapIdentifiers)
        let outboundOnlyIdentifiers = outboundIdentifiers.subtracting(overlapIdentifiers)

        var storedPositions: [String: CGPoint] = layoutSnapshot?.nodePositions.reduce(into: [:]) { partial, entry in
            partial[entry.nodeID] = CGPoint(x: entry.x, y: entry.y)
        } ?? [:]

        let snapshotHasMeaningfulLayout: Bool = {
            guard let snapshot = layoutSnapshot, !snapshot.nodePositions.isEmpty else { return false }
            let uniqueKeys = Set(snapshot.nodePositions.map { node -> String in
                let xKey = Int((node.x * 1000).rounded(.toNearestOrEven))
                let yKey = Int((node.y * 1000).rounded(.toNearestOrEven))
                return "\(xKey)-\(yKey)"
            })
            return uniqueKeys.count > 1
        }()

        if !snapshotHasMeaningfulLayout { storedPositions.removeAll() }

        func rowsRequired(for count: Int, columns: Int) -> Int {
            guard count > 0 else { return 0 }
            return Int(ceil(Double(count) / Double(columns)))
        }

        func makeLeftPosition(index: inout Int, total: Int) -> CGPoint {
            let columns = max(1, min(3, total))
            let column = index % columns
            let row = index / columns
            index += 1
            return CGPoint(x: -CGFloat(column + 1) * spacingX, y: CGFloat(row) * spacingY)
        }

        func makeRightPosition(index: inout Int, total: Int) -> CGPoint {
            let columns = max(1, min(3, total))
            let column = index % columns
            let row = index / columns
            index += 1
            return CGPoint(x: CGFloat(column + 1) * spacingX, y: CGFloat(row) * spacingY)
        }

        func makeTopPosition(index: inout Int, total: Int) -> CGPoint {
            let columns = max(1, min(4, total))
            let column = index % columns
            let row = index / columns
            index += 1
            let centeredColumn = CGFloat(column) - CGFloat(columns - 1) / 2
            return CGPoint(x: centeredColumn * spacingX * 0.9, y: -CGFloat(row + 1) * spacingY)
        }

        func makeBottomPosition(index: inout Int, total: Int, verticalOffset: Int) -> CGPoint {
            let columns = max(2, min(4, total))
            let column = index % columns
            let row = index / columns
            index += 1
            let centeredColumn = CGFloat(column) - CGFloat(columns - 1) / 2
            return CGPoint(x: centeredColumn * spacingX * 0.9, y: CGFloat(verticalOffset + row + 1) * spacingY)
        }

        let sortedKeys = tableDetails.keys.sorted { lhs, rhs in
            if lhs.schema.caseInsensitiveCompare(rhs.schema) == .orderedSame {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.schema.localizedCaseInsensitiveCompare(rhs.schema) == .orderedAscending
        }

        let overlapKeys = sortedKeys.filter { overlapIdentifiers.contains($0.identifier) }
        let inboundKeysOrdered = sortedKeys.filter { inboundOnlyIdentifiers.contains($0.identifier) }
        let outboundKeysOrdered = sortedKeys.filter { outboundOnlyIdentifiers.contains($0.identifier) }
        let neutralKeys = sortedKeys.filter { $0 != baseKey && !inboundIdentifiers.contains($0.identifier) && !outboundIdentifiers.contains($0.identifier) }

        let inboundRows = rowsRequired(for: inboundKeysOrdered.count, columns: max(1, min(3, inboundKeysOrdered.count)))
        let outboundRows = rowsRequired(for: outboundKeysOrdered.count, columns: max(1, min(3, outboundKeysOrdered.count)))
        let verticalOffsetForBottom = max(inboundRows, outboundRows)

        var leftIndex = 0, rightIndex = 0, topIndex = 0, bottomIndex = 0
        if storedPositions[baseIdentifier] == nil { storedPositions[baseIdentifier] = .zero }
        if overlapKeys.contains(baseKey) { storedPositions[baseIdentifier] = .zero }

        for key in overlapKeys where key != baseKey && storedPositions[key.identifier] == nil {
            storedPositions[key.identifier] = makeTopPosition(index: &topIndex, total: overlapKeys.count)
        }
        for key in inboundKeysOrdered where storedPositions[key.identifier] == nil {
            storedPositions[key.identifier] = makeLeftPosition(index: &leftIndex, total: inboundKeysOrdered.count)
        }
        for key in outboundKeysOrdered where storedPositions[key.identifier] == nil {
            storedPositions[key.identifier] = makeRightPosition(index: &rightIndex, total: outboundKeysOrdered.count)
        }
        for key in neutralKeys where storedPositions[key.identifier] == nil {
            storedPositions[key.identifier] = makeBottomPosition(index: &bottomIndex, total: neutralKeys.count, verticalOffset: max(1, verticalOffsetForBottom))
        }

        var nodeModels: [SchemaDiagramNodeModel] = []
        if let baseDetails = tableDetails[baseKey] {
            nodeModels.append(SchemaDiagramNodeModel(
                schema: baseKey.schema,
                name: baseKey.name,
                columns: buildColumns(for: baseDetails),
                indexes: buildIndexes(for: baseDetails),
                databaseName: databaseName,
                position: storedPositions[baseKey.identifier] ?? .zero
            ))
        }
        for key in sortedKeys where key != baseKey {
            guard let details = tableDetails[key] else { continue }
            nodeModels.append(SchemaDiagramNodeModel(
                schema: key.schema,
                name: key.name,
                columns: buildColumns(for: details),
                indexes: buildIndexes(for: details),
                databaseName: databaseName,
                position: storedPositions[key.identifier] ?? .zero
            ))
        }

        if !snapshotHasMeaningfulLayout {
            let minimumSeparation: CGFloat = 320
            for _ in 0..<12 {
                var didAdjust = false
                for i in nodeModels.indices {
                    for j in nodeModels.indices where j > i {
                        let lhs = nodeModels[i], rhs = nodeModels[j]
                        if lhs.id == rhs.id { continue }
                        let vector = CGPoint(x: rhs.position.x - lhs.position.x, y: rhs.position.y - lhs.position.y)
                        let distance = max(0.001, hypot(vector.x, vector.y))
                        if distance < minimumSeparation {
                            let overlap = (minimumSeparation - distance) / 2
                            let angle = distance < 0.01 ? (Double(i + j).truncatingRemainder(dividingBy: 8) / 8.0) * 2 * .pi : atan2(vector.y, vector.x)
                            let adjustX = CGFloat(cos(angle)) * overlap, adjustY = CGFloat(sin(angle)) * overlap
                            if lhs.id == baseIdentifier { nodeModels[j].position = CGPoint(x: nodeModels[j].position.x + adjustX * 2, y: nodeModels[j].position.y + adjustY * 2) }
                            else if rhs.id == baseIdentifier { nodeModels[i].position = CGPoint(x: nodeModels[i].position.x - adjustX * 2, y: nodeModels[i].position.y - adjustY * 2) }
                            else {
                                nodeModels[i].position = CGPoint(x: nodeModels[i].position.x - adjustX, y: nodeModels[i].position.y - adjustY)
                                nodeModels[j].position = CGPoint(x: nodeModels[j].position.x + adjustX, y: nodeModels[j].position.y + adjustY)
                            }
                            didAdjust = true
                        }
                    }
                }
                if !didAdjust { break }
            }
        }

        for (key, details) in tableDetails { appendForeignKeyEdges(from: key, details: details) }

        return SchemaDiagramViewModel(
            nodes: nodeModels,
            edges: edges,
            baseNodeID: baseKey.identifier,
            title: title,
            layoutIdentifier: layoutSnapshot?.layoutID ?? "primary",
            cachedStructure: structureSnapshot,
            cachedChecksum: checksum,
            loadSource: loadSource
        )
    }
}
