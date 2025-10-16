import SwiftUI

#if os(macOS)
import AppKit
#endif

struct SchemaDiagramView: View {
    @ObservedObject var viewModel: SchemaDiagramViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var zoom: CGFloat = 1.0
    @State private var contentOffset: CGSize = .zero
    @State private var lastDragOffset: CGSize = .zero
    @State private var hasCenteredDiagram = false

    private let minZoom: CGFloat = 0.4
    private let maxZoom: CGFloat = 2.5

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundGrid(in: geometry.size)

                DiagramCanvas(
                    viewModel: viewModel,
                    zoom: zoom,
                    offset: contentOffset
                )

                zoomControls
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .clipped()
            .gesture(panGesture)
            .gesture(magnificationGesture, including: .gesture)
            .overlay(CommandScrollZoomCapture { delta in
                applyZoom(from: delta)
            })
            .onAppear {
                centerDiagramIfNeeded(in: geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                centerDiagramIfNeeded(in: newSize)
            }
        }
        .navigationTitle(viewModel.title)
    }

    private var zoomControls: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        updateZoom(to: max(minZoom, zoom - 0.1))
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .buttonStyle(.bordered)

                    Slider(value: Binding(
                        get: { zoom },
                        set: { updateZoom(to: $0) }
                    ), in: minZoom...maxZoom)
                    .frame(width: 160)

                    Button {
                        updateZoom(to: min(maxZoom, zoom + 0.1))
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(10)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                .padding(.bottom, 24)
                .padding(.trailing, 24)
            }
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                updateZoom(to: max(minZoom, min(maxZoom, zoom * scale)))
            }
            .onEnded { scale in
                updateZoom(to: max(minZoom, min(maxZoom, zoom * scale)))
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .local)
            .onChanged { value in
                contentOffset = CGSize(
                    width: lastDragOffset.width + value.translation.width,
                    height: lastDragOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastDragOffset = contentOffset
            }
    }

    private func updateZoom(to newValue: CGFloat) {
        let clamped = max(minZoom, min(maxZoom, newValue))
        zoom = clamped
    }

    private func applyZoom(from delta: CGFloat) {
        let sensitivity: CGFloat = 0.01
        let adjustment = 1 + (-delta * sensitivity)
        updateZoom(to: zoom * adjustment)
    }

    private func centerDiagramIfNeeded(in size: CGSize) {
        guard !hasCenteredDiagram else { return }
        hasCenteredDiagram = true
        let initialOffset = CGSize(width: size.width / 2, height: size.height / 2)
        contentOffset = initialOffset
        lastDragOffset = initialOffset
    }

    private func backgroundGrid(in size: CGSize) -> some View {
        let gridColor = Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06)
        let spacing: CGFloat = 64
        return Canvas { context, canvasSize in
            let step = spacing * zoom
            guard step > 8 else { return }
            var path = Path()

            var x: CGFloat = 0
            while x <= canvasSize.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                x += step
            }

            var y: CGFloat = 0
            while y <= canvasSize.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                y += step
            }

            context.stroke(path, with: .color(gridColor), lineWidth: 1)
        }
        .offset(contentOffset)
    }
}

private struct DiagramCanvas: View {
    @ObservedObject var viewModel: SchemaDiagramViewModel
    let zoom: CGFloat
    let offset: CGSize

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(viewModel.nodes) { node in
                    SchemaDiagramNodeView(node: node, zoom: zoom)
                        .position(position(for: node.position))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .scaleEffect(zoom, anchor: .topLeading)
            .offset(offset)
            .background(
                Color.clear
                    .overlayPreferenceValue(DiagramColumnAnchorPreferenceKey.self) { anchors in
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
        let pathWidth: CGFloat = 1.6
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(.accentColor.opacity(0.9)), lineWidth: pathWidth)

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
        context.fill(arrowPath, with: .color(.accentColor.opacity(0.9)))
    }
}

private struct SchemaDiagramNodeView: View {
    @ObservedObject var node: SchemaDiagramNodeModel
    let zoom: CGFloat

    @State private var dragStartPosition: CGPoint = .zero

    private let headerColor = Color.accentColor.opacity(0.2)
    private let borderColor = Color.primary.opacity(0.12)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .foregroundStyle(Color.primary.opacity(0.08))
            columnsList
        }
        .frame(minWidth: 220, idealWidth: 240)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 6)
        .gesture(dragGesture)
        .onAppear {
            dragStartPosition = node.position
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(node.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(node.schema)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(headerColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private var columnsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(node.columns) { column in
                ColumnRow(nodeID: node.id, column: column)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let adjusted = CGPoint(
                    x: dragStartPosition.x + value.translation.width / zoom,
                    y: dragStartPosition.y + value.translation.height / zoom
                )
                node.position = adjusted
            }
            .onEnded { _ in
                dragStartPosition = node.position
            }
    }
}

private struct ColumnRow: View {
    let nodeID: String
    let column: SchemaDiagramColumn

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: columnIconName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(iconColor)
            Text(column.name)
                .font(.system(size: 12, weight: column.isPrimaryKey ? .semibold : .regular))
                .foregroundStyle(Color.primary)
            Spacer()
            Text(column.dataType)
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(column.isForeignKey ? 0.06 : 0))
        )
        .anchorPreference(key: DiagramColumnAnchorPreferenceKey.self, value: .bounds) {
            [DiagramColumnAnchor(nodeID: nodeID, columnName: column.name, bounds: $0)]
        }
    }

    private var columnIconName: String {
        if column.isPrimaryKey {
            return "key.fill"
        }
        if column.isForeignKey {
            return "arrow.turn.down.right"
        }
        return "circle.fill"
    }

    private var iconColor: Color {
        if column.isPrimaryKey || column.isForeignKey {
            return .accentColor
        }
        return .secondary
    }
}

private struct DiagramColumnAnchor: Identifiable {
    let id = UUID()
    let nodeID: String
    let columnName: String
    let bounds: Anchor<CGRect>

    static func key(nodeID: String, columnName: String) -> String {
        "\(nodeID)#\(columnName)"
    }
}

private struct DiagramColumnAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [DiagramColumnAnchor] = []

    static func reduce(value: inout [DiagramColumnAnchor], nextValue: () -> [DiagramColumnAnchor]) {
        value.append(contentsOf: nextValue())
    }
}

#if os(macOS)
private struct CommandScrollZoomCapture: NSViewRepresentable {
    let onZoom: (CGFloat) -> Void

    func makeNSView(context: Context) -> ZoomCaptureView {
        let view = ZoomCaptureView()
        view.onZoom = onZoom
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ nsView: ZoomCaptureView, context: Context) {
        nsView.onZoom = onZoom
    }

    final class ZoomCaptureView: NSView {
        var onZoom: ((CGFloat) -> Void)?

        override func scrollWheel(with event: NSEvent) {
            if event.modifierFlags.contains(.command) {
                onZoom?(event.scrollingDeltaY)
            } else {
                super.scrollWheel(with: event)
            }
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }
    }
}
#else
private struct CommandScrollZoomCapture: View {
    let onZoom: (CGFloat) -> Void
    var body: some View { Color.clear }
}
#endif
