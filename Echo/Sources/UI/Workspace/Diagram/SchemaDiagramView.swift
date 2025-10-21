import SwiftUI

#if os(macOS)
import AppKit
#endif

struct SchemaDiagramView: View {
    @ObservedObject var viewModel: SchemaDiagramViewModel
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var zoom: CGFloat = 1.0
    @State private var contentOffset: CGSize = .zero
    @State private var lastDragOffset: CGSize = .zero
    @State private var hasCenteredDiagram = false
    @State private var isDraggingNode = false
    @State private var persistTask: Task<Void, Never>?
    @State private var isRefreshing = false
    @State private var lastKnownNodeCount: Int = 0
    @State private var lastLoadingState: Bool = false

    private let minZoom: CGFloat = 0.4
    private let maxZoom: CGFloat = 2.5

    var body: some View {
        GeometryReader { geometry in
            let shouldRenderEdges: Bool = {
                if viewModel.edges.count <= 200 {
                    return true
                }
                return appModel.globalSettings.diagramRenderRelationshipsForLargeDiagrams
            }()
            ZStack {
                backgroundGrid(in: geometry.size)

                DiagramCanvas(
                    viewModel: viewModel,
                    zoom: zoom,
                    offset: contentOffset,
                    palette: palette,
                    renderEdges: shouldRenderEdges,
                    isDraggingNode: $isDraggingNode,
                    onLayoutCommitted: persistLayout
                )

                zoomControls
            }
            .background(palette.canvasBackground)
            .clipped()
            .gesture(panGesture)
            .gesture(magnificationGesture, including: .gesture)
            .overlay(CommandScrollZoomCapture { delta in
                applyZoom(from: delta)
            })
            .onAppear {
                centerDiagram(in: geometry.size)
                lastKnownNodeCount = viewModel.nodes.count
                lastLoadingState = viewModel.isLoading
            }
            .onChange(of: geometry.size) { _, newSize in
                centerDiagram(in: newSize)
            }
            .onChange(of: viewModel.nodes.count) { oldValue, newValue in
                if oldValue == 1 && newValue > 1 {
                    centerDiagram(in: geometry.size, force: true)
                }
                lastKnownNodeCount = newValue
            }
            .onChange(of: viewModel.isLoading) { oldValue, newValue in
                if oldValue && !newValue {
                    centerDiagram(in: geometry.size, force: true)
                }
                lastLoadingState = newValue
            }
            .overlay(statusOverlay)
            .overlay(alignment: .topTrailing) {
                toolbarOverlay
                    .padding(.top, 16)
                    .padding(.trailing, 16)
            }
        }
        .navigationTitle(viewModel.title)
    }

    private var palette: DiagramPalette {
        if appModel.globalSettings.diagramUseThemedAppearance {
            let theme = themeManager.activeTheme
            let accent = theme.accent?.color ?? themeManager.accentColor
            let foreground = theme.surfaceForeground.color
            let detail = foreground.opacity(0.65)
            let nodeShadow = Color.black.opacity(colorScheme == .dark ? 0.45 : 0.18)
            return DiagramPalette(
                canvasBackground: theme.windowBackground.color,
                gridLine: foreground.opacity(0.12),
                nodeBackground: theme.surfaceBackground.color.opacity(0.95),
                nodeBorder: foreground.opacity(0.14),
                nodeShadow: nodeShadow,
                headerBackground: accent.opacity(0.22),
                headerBorder: accent.opacity(0.45),
                headerTitle: foreground,
                headerSubtitle: detail,
                columnText: foreground,
                columnDetail: detail,
                columnHighlight: accent.opacity(0.12),
                accent: accent,
                edgeColor: accent.opacity(0.9),
                overlayBackground: theme.surfaceBackground.color.opacity(0.96),
                overlayBorder: foreground.opacity(0.14)
            )
        } else {
            let canvasBackground = Color(nsColor: .windowBackgroundColor)
            let controlBackground = Color(nsColor: .controlBackgroundColor)
            let primary = Color.primary
            let secondary = Color.secondary
            let accent = Color.accentColor
            let shadow = Color.black.opacity(colorScheme == .dark ? 0.5 : 0.16)
            return DiagramPalette(
                canvasBackground: canvasBackground,
                gridLine: primary.opacity(colorScheme == .dark ? 0.14 : 0.08),
                nodeBackground: controlBackground.opacity(colorScheme == .dark ? 0.85 : 1.0),
                nodeBorder: primary.opacity(0.12),
                nodeShadow: shadow,
                headerBackground: accent.opacity(0.18),
                headerBorder: accent.opacity(0.35),
                headerTitle: primary,
                headerSubtitle: secondary,
                columnText: primary,
                columnDetail: secondary,
                columnHighlight: accent.opacity(0.08),
                accent: accent.opacity(0.9),
                edgeColor: accent.opacity(0.85),
                overlayBackground: canvasBackground.opacity(0.98),
                overlayBorder: primary.opacity(0.08)
            )
        }
    }

    private func persistLayout() {
        persistTask?.cancel()
        persistTask = Task { @MainActor [viewModel] in
            await appModel.persistDiagramLayout(viewModel)
            persistTask = nil
        }
    }

    private var toolbarOverlay: some View {
        HStack(spacing: 12) {
            loadSourceBadge
            if isRefreshing || viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Button {
                guard !isRefreshing else { return }
                isRefreshing = true
                Task {
                    await appModel.refreshDiagram(viewModel)
                    await MainActor.run {
                        isRefreshing = false
                    }
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }

    private var loadSourceBadge: some View {
        let descriptor = loadSourceDescriptor(for: viewModel.loadSource)
        return Label(descriptor.text, systemImage: descriptor.icon)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(descriptor.background, in: Capsule())
            .foregroundColor(descriptor.foreground)
    }

    private func loadSourceDescriptor(for source: DiagramLoadSource) -> (text: String, icon: String, foreground: Color, background: Color) {
        switch source {
        case .live(let date):
            return (
                "Live · " + relativeTimeString(since: date),
                "bolt.fill",
                Color.green.opacity(0.9),
                Color.green.opacity(0.15)
            )
        case .cache(let date):
            return (
                "Cached · " + relativeTimeString(since: date),
                "clock.arrow.circlepath",
                Color.blue.opacity(0.9),
                Color.blue.opacity(0.15)
            )
        }
    }

    private func relativeTimeString(since date: Date) -> String {
        let formatter = SchemaDiagramView.relativeFormatter
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

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
                guard !isDraggingNode else { return }
                contentOffset = CGSize(
                    width: lastDragOffset.width + value.translation.width,
                    height: lastDragOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard !isDraggingNode else { return }
                lastDragOffset = contentOffset
            }
    }

    private func updateZoom(to newValue: CGFloat) {
        let clamped = max(minZoom, min(maxZoom, newValue))
        let basePosition = viewModel.node(for: viewModel.baseNodeID)?.position ?? .zero
        let currentCenter = CGPoint(x: basePosition.x * zoom, y: basePosition.y * zoom)
        let newCenter = CGPoint(x: basePosition.x * clamped, y: basePosition.y * clamped)
        let deltaOffset = CGSize(
            width: currentCenter.x - newCenter.x,
            height: currentCenter.y - newCenter.y
        )
        zoom = clamped
        let adjustedOffset = CGSize(
            width: contentOffset.width + deltaOffset.width,
            height: contentOffset.height + deltaOffset.height
        )
        contentOffset = adjustedOffset
        lastDragOffset = adjustedOffset
    }

    private func applyZoom(from delta: CGFloat) {
        let sensitivity: CGFloat = 0.01
        let adjustment = 1 + (-delta * sensitivity)
        updateZoom(to: zoom * adjustment)
    }

    private func centerDiagram(in size: CGSize, force: Bool = false) {
        if force {
            hasCenteredDiagram = false
        }
        guard !hasCenteredDiagram else { return }
        guard size.width.isFinite, size.height.isFinite else { return }
        let basePosition = viewModel.node(for: viewModel.baseNodeID)?.position ?? .zero
        let centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
        let scaledBase = CGPoint(x: basePosition.x * zoom, y: basePosition.y * zoom)
        let targetOffset = CGSize(
            width: centerPoint.x - scaledBase.x,
            height: centerPoint.y - scaledBase.y
        )
        contentOffset = targetOffset
        lastDragOffset = targetOffset
        hasCenteredDiagram = true
    }

    private func backgroundGrid(in size: CGSize) -> some View {
        let gridColor = palette.gridLine
        let spacing: CGFloat = 64
        return Canvas { context, canvasSize in
            let step = spacing * zoom
            guard step > 8 else { return }
            var path = Path()

            let xRemainder = contentOffset.width.truncatingRemainder(dividingBy: step)
            let yRemainder = contentOffset.height.truncatingRemainder(dividingBy: step)

            var x: CGFloat = -step * 2 - xRemainder
            while x <= canvasSize.width + step * 2 {
                path.move(to: CGPoint(x: x, y: -step * 2))
                path.addLine(to: CGPoint(x: x, y: canvasSize.height + step * 2))
                x += step
            }

            var y: CGFloat = -step * 2 - yRemainder
            while y <= canvasSize.height + step * 2 {
                path.move(to: CGPoint(x: -step * 2, y: y))
                path.addLine(to: CGPoint(x: canvasSize.width + step * 2, y: y))
                y += step
            }

            context.stroke(path, with: .color(gridColor), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        if let error = viewModel.errorMessage {
            blockingStatusCard(
                icon: "exclamationmark.triangle.fill",
                tint: palette.accent,
                title: "Unable to Load Diagram",
                message: error
            )
        } else if viewModel.isLoading && viewModel.nodes.isEmpty {
            blockingStatusCard(
                icon: nil,
                tint: palette.accent,
                title: "Loading Diagram…",
                message: viewModel.statusMessage ?? "Fetching structure and relationships"
            )
        } else if let message = viewModel.statusMessage, !message.isEmpty {
            bannerStatus(message: message, showsProgress: viewModel.isLoading)
        }
    }

    private func blockingStatusCard(
        icon: String?,
        tint: Color,
        title: String,
        message: String
    ) -> some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 16) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(tint)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(width: 240)
                        .tint(tint)
                }
                VStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(palette.headerTitle)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(palette.headerSubtitle)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(palette.overlayBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(palette.overlayBorder, lineWidth: 1)
                    )
            )
            .shadow(color: palette.nodeShadow.opacity(0.7), radius: 18, x: 0, y: 12)
        }
    }

    private func bannerStatus(message: String, showsProgress: Bool) -> some View {
        VStack {
            HStack {
                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                        .tint(palette.accent)
                } else {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
                Text(message)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.headerTitle)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.overlayBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(palette.overlayBorder, lineWidth: 1)
                    )
            )
            .shadow(color: palette.nodeShadow.opacity(0.4), radius: 12, x: 0, y: 6)
            .padding(.top, 16)
            .padding(.horizontal, 24)

            Spacer()
        }
        .allowsHitTesting(false)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: showsProgress)
    }
}

private struct DiagramCanvas: View {
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

private struct SchemaDiagramNodeView: View {
    @ObservedObject var node: SchemaDiagramNodeModel
    let zoom: CGFloat
    let palette: DiagramPalette
    @Binding var isDraggingNode: Bool
    let onPositionCommitted: () -> Void

    @State private var dragStartPosition: CGPoint?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .foregroundStyle(palette.nodeBorder)
            columnsList
        }
        .fixedSize(horizontal: true, vertical: false)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.nodeBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.nodeBorder, lineWidth: 1)
        )
        .shadow(color: palette.nodeShadow, radius: 16, x: 0, y: 6)
        .highPriorityGesture(dragGesture)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(node.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.headerTitle)
            Text(node.schema)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.headerSubtitle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.headerBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(palette.headerBorder, lineWidth: 1)
                )
        )
    }

    private var columnsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(node.columns) { column in
                ColumnRow(nodeID: node.id, column: column, palette: palette)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartPosition == nil {
                    dragStartPosition = node.position
                }
                if !isDraggingNode {
                    isDraggingNode = true
                }
                let origin = dragStartPosition ?? node.position
                let delta = CGSize(
                    width: value.translation.width / zoom,
                    height: value.translation.height / zoom
                )
                let newPosition = CGPoint(
                    x: origin.x + delta.width,
                    y: origin.y + delta.height
                )
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    node.position = newPosition
                }
            }
            .onEnded { value in
                let origin = dragStartPosition ?? node.position
                let delta = CGSize(
                    width: value.translation.width / zoom,
                    height: value.translation.height / zoom
                )
                let newPosition = CGPoint(
                    x: origin.x + delta.width,
                    y: origin.y + delta.height
                )
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    node.position = newPosition
                }
                dragStartPosition = nil
                isDraggingNode = false
                onPositionCommitted()
            }
    }
}

private struct ColumnRow: View {
    let nodeID: String
    let column: SchemaDiagramColumn
    let palette: DiagramPalette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: columnIconName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(iconColor)
            Text(column.name)
                .lineLimit(1)
                .layoutPriority(1)
                .font(.system(size: 12, weight: column.isPrimaryKey ? .semibold : .regular))
                .foregroundStyle(palette.columnText)
            Spacer(minLength: 12)
            Text(column.dataType)
                .lineLimit(1)
                .font(.system(size: 11))
                .foregroundStyle(palette.columnDetail)
        }
        .padding(.vertical, 4)
        .fixedSize(horizontal: true, vertical: false)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(columnHighlightColor)
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
            return palette.accent
        }
        return palette.columnDetail
    }

    private var columnHighlightColor: Color {
        (column.isPrimaryKey || column.isForeignKey) ? palette.columnHighlight : Color.clear
    }
}

private struct DiagramPalette {
    let canvasBackground: Color
    let gridLine: Color
    let nodeBackground: Color
    let nodeBorder: Color
    let nodeShadow: Color
    let headerBackground: Color
    let headerBorder: Color
    let headerTitle: Color
    let headerSubtitle: Color
    let columnText: Color
    let columnDetail: Color
    let columnHighlight: Color
    let accent: Color
    let edgeColor: Color
    let overlayBackground: Color
    let overlayBorder: Color
}

private struct DiagramColumnAnchor: Identifiable {
    let nodeID: String
    let columnName: String
    let bounds: Anchor<CGRect>

    var id: String { Self.key(nodeID: nodeID, columnName: columnName) }

    static func key(nodeID: String, columnName: String) -> String {
        "\(nodeID.diagramAnchorComponent)#\(columnName.diagramAnchorComponent)"
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
        private var scrollMonitor: Any?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            translatesAutoresizingMaskIntoConstraints = false
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                installMonitorIfNeeded()
            }
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil {
                removeMonitor()
            }
            super.viewWillMove(toWindow: newWindow)
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        deinit {
            removeMonitor()
        }

        private func installMonitorIfNeeded() {
            guard scrollMonitor == nil else { return }
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self,
                      let window = self.window,
                      event.window === window,
                      event.modifierFlags.contains(.command) else {
                    return event
                }
                self.onZoom?(event.scrollingDeltaY)
                return nil
            }
        }

        private func removeMonitor() {
            if let monitor = scrollMonitor {
                NSEvent.removeMonitor(monitor)
                scrollMonitor = nil
            }
        }
    }
}
#else
private struct CommandScrollZoomCapture: View {
    let onZoom: (CGFloat) -> Void
    var body: some View { Color.clear }
}
#endif

private extension String {
    var diagramAnchorComponent: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
