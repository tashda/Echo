import SwiftUI
import EchoSense

struct DiagramCanvas: View {
    @ObservedObject var viewModel: SchemaDiagramViewModel
    let zoom: CGFloat
    let offset: CGSize
    let palette: DiagramPalette
    let renderEdges: Bool
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
                        .position(position(for: node.position))
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
                to: endPoint
            )
        }
    }

    private func drawConnection(
        context: inout GraphicsContext,
        from start: CGPoint,
                to end: CGPoint
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
    }
}
