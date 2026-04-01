import SwiftUI
import EchoSense

struct DiagramCanvas: View {
    @Bindable var viewModel: SchemaDiagramViewModel
    let zoom: CGFloat
    let offset: CGSize
    let palette: DiagramPalette
    let renderEdges: Bool
    let showIndexes: Bool
    let searchFilter: String
    @Binding var isDraggingNode: Bool
    let onLayoutCommitted: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(viewModel.nodes) { node in
                    SchemaDiagramNodeView(
                        node: node,
                        zoom: zoom,
                        palette: palette,
                        isDraggingNode: $isDraggingNode,
                        onPositionCommitted: onLayoutCommitted
                    )
                        .opacity(nodeMatchesSearch(node) ? 1.0 : 0.2)
                        .position(position(for: node.position))
                }

                // Index nodes rendered as separate bubbles near their parent table
                if showIndexes {
                    ForEach(viewModel.nodes) { node in
                        ForEach(Array(node.indexes.enumerated()), id: \.element.id) { offset, index in
                            SchemaDiagramIndexNodeView(
                                index: index,
                                palette: palette,
                                position: indexPosition(for: node, indexOffset: offset),
                                zoom: zoom
                            )
                            .opacity(nodeMatchesSearch(node) ? 0.85 : 0.15)
                            .position(position(for: indexPosition(for: node, indexOffset: offset)))
                        }
                    }
                }

                ForEach(viewModel.annotations) { annotation in
                    DiagramAnnotationView(
                        annotation: annotation,
                        zoom: zoom,
                        onUpdate: { text in viewModel.updateAnnotation(id: annotation.id, text: text) },
                        onDelete: { viewModel.removeAnnotation(id: annotation.id) }
                    )
                    .position(position(for: annotation.position))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingNode = true
                                let effectiveZoom = max(zoom, 0.5)
                                let delta = CGSize(
                                    width: value.translation.width / effectiveZoom,
                                    height: value.translation.height / effectiveZoom
                                )
                                viewModel.moveAnnotation(
                                    id: annotation.id,
                                    to: CGPoint(
                                        x: annotation.position.x + delta.width,
                                        y: annotation.position.y + delta.height
                                    )
                                )
                            }
                            .onEnded { _ in
                                isDraggingNode = false
                            }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .scaleEffect(zoom, anchor: .topLeading)
            .offset(offset)
            .background(
                Color.clear
                    .overlayPreferenceValue(DiagramColumnAnchorPreferenceKey.self) { anchors in
                        if renderEdges {
                            Canvas { context, size in
                                renderEdges(
                                    context: &context,
                                    anchors: anchors,
                                    size: size,
                                    geometry: geometry
                                )
                            }
                            .allowsHitTesting(false)
                            .scaleEffect(zoom, anchor: .topLeading)
                            .offset(offset)
                        } else {
                            EmptyView()
                        }
                    }
            )
        }
    }

    private func position(for basePoint: CGPoint) -> CGPoint {
        CGPoint(x: basePoint.x, y: basePoint.y)
    }

    private func indexPosition(for node: SchemaDiagramNodeModel, indexOffset: Int) -> CGPoint {
        // Position indexes to the right of the table node, stacked vertically
        let xOffset: CGFloat = 280
        let ySpacing: CGFloat = 50
        let estimatedNodeHeight = CGFloat(node.columns.count) * 20 + 60
        let startY = node.position.y - estimatedNodeHeight / 2
        return CGPoint(
            x: node.position.x + xOffset,
            y: startY + CGFloat(indexOffset) * ySpacing
        )
    }

    private func nodeMatchesSearch(_ node: SchemaDiagramNodeModel) -> Bool {
        let query = searchFilter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return true }
        return node.name.lowercased().contains(query)
            || node.schema.lowercased().contains(query)
            || node.displayName.lowercased().contains(query)
    }

    private func renderEdges(
        context: inout GraphicsContext,
        anchors: [DiagramColumnAnchor],
        size: CGSize,
        geometry: GeometryProxy
    ) {
        let anchorMap = anchors.reduce(into: [String: Anchor<CGRect>]()) { partialResult, item in
            let key = DiagramColumnAnchor.key(nodeID: item.nodeID, columnName: item.columnName)
            partialResult[key] = item.bounds
        }

        for edge in viewModel.edges {
            let startKey = DiagramColumnAnchor.key(nodeID: edge.fromNodeID, columnName: edge.fromColumn)
            let endKey = DiagramColumnAnchor.key(nodeID: edge.toNodeID, columnName: edge.toColumn)

            guard let startAnchor = anchorMap[startKey],
                  let endAnchor = anchorMap[endKey] else { continue }

            let startRect = geometry[startAnchor]
            let endRect = geometry[endAnchor]

            let startPoint = CGPoint(x: startRect.midX, y: startRect.midY)
            let endPoint = CGPoint(x: endRect.midX, y: endRect.midY)

            drawConnection(
                context: &context,
                from: startPoint,
                to: endPoint,
                edge: edge
            )
        }
    }

    private func drawConnection(
        context: inout GraphicsContext,
        from start: CGPoint,
        to end: CGPoint,
        edge: SchemaDiagramEdge
    ) {
        let strokeColor = palette.edgeColor
        var backgroundPath = Path()
        backgroundPath.move(to: start)
        backgroundPath.addLine(to: end)
        context.stroke(
            backgroundPath,
            with: .color(strokeColor.opacity(0.2)),
            style: StrokeStyle(lineWidth: 5.0, lineCap: .round, lineJoin: .round)
        )

        let pathWidth: CGFloat = 2.4
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(
            path,
            with: .color(strokeColor),
            style: StrokeStyle(lineWidth: pathWidth, lineCap: .round)
        )

        let arrowLength: CGFloat = 14
        let arrowAngle: CGFloat = .pi / 7
        let angle = atan2(end.y - start.y, end.x - start.x)

        let point1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )

        var arrowPath = Path()
        arrowPath.move(to: end)
        arrowPath.addLine(to: point1)
        arrowPath.addLine(to: point2)
        arrowPath.closeSubpath()
        context.fill(arrowPath, with: .color(strokeColor))

        // Cardinality indicators: "1" at the FK (start/referencing) side, "N" at the referenced side
        let labelFont = Font.system(size: 10, weight: .semibold, design: .rounded)
        let labelColor = strokeColor.opacity(0.85)
        let perpAngle = angle + .pi / 2
        let perpOffset: CGFloat = 10

        let onePos = CGPoint(
            x: start.x + 20 * cos(angle) + perpOffset * cos(perpAngle),
            y: start.y + 20 * sin(angle) + perpOffset * sin(perpAngle)
        )
        let manyPos = CGPoint(
            x: end.x - 28 * cos(angle) + perpOffset * cos(perpAngle),
            y: end.y - 28 * sin(angle) + perpOffset * sin(perpAngle)
        )

        context.draw(
            Text("1").font(labelFont).foregroundStyle(labelColor),
            at: onePos,
            anchor: .center
        )
        context.draw(
            Text("N").font(labelFont).foregroundStyle(labelColor),
            at: manyPos,
            anchor: .center
        )

        // FK name label at midpoint
        if let fkName = edge.relationshipName, !fkName.isEmpty {
            let midPoint = CGPoint(
                x: (start.x + end.x) / 2 + perpOffset * cos(perpAngle),
                y: (start.y + end.y) / 2 + perpOffset * sin(perpAngle)
            )
            let fkFont = Font.system(size: 9, weight: .medium, design: .monospaced)
            context.draw(
                Text(fkName).font(fkFont).foregroundStyle(strokeColor.opacity(0.6)),
                at: midPoint,
                anchor: .center
            )
        }
    }
}
