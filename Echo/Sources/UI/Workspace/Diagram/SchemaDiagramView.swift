import SwiftUI

#if os(macOS)
import AppKit
#endif
import EchoSense

struct SchemaDiagramView: View {
    @ObservedObject var viewModel: SchemaDiagramViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(DiagramCoordinator.self) private var diagramCoordinator
    
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
                return projectStore.globalSettings.diagramRenderRelationshipsForLargeDiagrams
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
        let accent = themeManager.accentColor
        let foreground = ColorTokens.Text.primary
        let detail = ColorTokens.Text.secondary
        let nodeShadow = Color.black.opacity(colorScheme == .dark ? 0.45 : 0.18)
        let canvasBackground = ColorTokens.Background.primary
        let surfaceBackground = ColorTokens.Background.secondary
        let controlBackground = ColorTokens.Background.tertiary
        
        if projectStore.globalSettings.diagramUseThemedAppearance {
            return DiagramPalette(
                canvasBackground: canvasBackground,
                gridLine: foreground.opacity(0.12),
                nodeBackground: surfaceBackground.opacity(0.95),
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
                overlayBackground: surfaceBackground.opacity(0.96),
                overlayBorder: foreground.opacity(0.14)
            )
        } else {
            let shadow = Color.black.opacity(colorScheme == .dark ? 0.5 : 0.16)
            return DiagramPalette(
                canvasBackground: canvasBackground,
                gridLine: foreground.opacity(colorScheme == .dark ? 0.14 : 0.08),
                nodeBackground: controlBackground.opacity(colorScheme == .dark ? 0.85 : 1.0),
                nodeBorder: foreground.opacity(0.12),
                nodeShadow: shadow,
                headerBackground: accent.opacity(0.18),
                headerBorder: accent.opacity(0.35),
                headerTitle: foreground,
                headerSubtitle: detail,
                columnText: foreground,
                columnDetail: detail,
                columnHighlight: accent.opacity(0.08),
                accent: accent.opacity(0.9),
                edgeColor: accent.opacity(0.85),
                overlayBackground: canvasBackground.opacity(0.98),
                overlayBorder: foreground.opacity(0.08)
            )
        }
    }

    private func persistLayout() {
        persistTask?.cancel()
        persistTask = Task { @MainActor [viewModel] in
            await diagramCoordinator.persistDiagramLayout(for: viewModel)
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
                    await diagramCoordinator.refreshDiagram(for: viewModel)
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
            DiagramBlockingStatusCard(
                icon: "exclamationmark.triangle.fill",
                tint: palette.accent,
                title: "Unable to Load Diagram",
                message: error,
                palette: palette
            )
        } else if viewModel.isLoading && viewModel.nodes.isEmpty {
            DiagramBlockingStatusCard(
                icon: nil,
                tint: palette.accent,
                title: "Loading Diagram…",
                message: viewModel.statusMessage ?? "Fetching structure and relationships",
                palette: palette
            )
        } else if let message = viewModel.statusMessage, !message.isEmpty {
            DiagramBannerStatus(message: message, showsProgress: viewModel.isLoading, palette: palette)
        }
    }
}
