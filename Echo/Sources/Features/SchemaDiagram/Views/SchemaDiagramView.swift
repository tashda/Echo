import SwiftUI

#if os(macOS)
import AppKit
#endif
import EchoSense

struct SchemaDiagramView: View {
    @Bindable var viewModel: SchemaDiagramViewModel
    @Environment(\.colorScheme) var colorScheme

    @Environment(ProjectStore.self) var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(DiagramBuilder.self) private var diagramBuilder

    @Environment(AppearanceStore.self) var appearanceStore

    @State internal var zoom: CGFloat = 1.0
    @State internal var contentOffset: CGSize = .zero
    @State internal var lastDragOffset: CGSize = .zero
    @State internal var hasCenteredDiagram = false
    @State internal var isDraggingNode = false
    @State private var persistTask: Task<Void, Never>?
    @State private var isRefreshing = false
    @State private var lastKnownNodeCount: Int = 0
    @State private var lastLoadingState: Bool = false
    @State internal var viewSize: CGSize = .zero
    @State internal var diagramSearchText: String = ""

    internal let minZoom: CGFloat = 0.4
    internal let maxZoom: CGFloat = 2.5

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
                    searchFilter: diagramSearchText,
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
                viewSize = geometry.size
                centerDiagram(in: geometry.size)
                lastKnownNodeCount = viewModel.nodes.count
                lastLoadingState = viewModel.isLoading
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
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
            .overlay(alignment: .bottomLeading) {
                if !viewModel.nodes.isEmpty && viewModel.nodes.count > 1 {
                    DiagramMinimapView(
                        nodes: viewModel.nodes,
                        zoom: zoom,
                        offset: contentOffset,
                        viewSize: viewSize,
                        palette: palette
                    )
                    .padding(.bottom, SpacingTokens.xl2)
                    .padding(.leading, SpacingTokens.md)
                }
            }
            .overlay(alignment: .topTrailing) {
                toolbarOverlay
                    .padding(.top, SpacingTokens.md)
                    .padding(.trailing, SpacingTokens.md)
            }
        }
        .navigationTitle(viewModel.title)
    }

    private func persistLayout() {
        persistTask?.cancel()
        persistTask = Task { @MainActor [viewModel] in
            await diagramBuilder.persistDiagramLayout(for: viewModel)
            persistTask = nil
        }
    }

    private var toolbarOverlay: some View {
        HStack(spacing: SpacingTokens.sm) {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .font(TypographyTokens.caption2)
                TextField("Filter tables\u{2026}", text: $diagramSearchText)
                    .textFieldStyle(.plain)
                    .font(TypographyTokens.caption2)
                    .frame(width: 120)
                if !diagramSearchText.isEmpty {
                    Button {
                        diagramSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear Search")
                    .accessibilityLabel("Clear Search")
                }
            }

            Divider()
                .frame(height: 16)

            Menu {
                Button("Export as PNG") { exportDiagram(as: .png) }
                Button("Export as PDF") { exportDiagram(as: .pdf) }
                Divider()
                Button("Print") { printDiagram() }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Export Diagram")
            .accessibilityLabel("Export Diagram")

            Divider()
                .frame(height: 16)

            loadSourceBadge
            if isRefreshing || viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Button {
                guard !isRefreshing else { return }
                isRefreshing = true
                Task {
                    await diagramBuilder.refreshDiagram(for: viewModel)
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
            .help("Refresh Diagram")
            .accessibilityLabel("Refresh Diagram")
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }

    private var loadSourceBadge: some View {
        let descriptor = loadSourceDescriptor(for: viewModel.loadSource)
        return Label(descriptor.text, systemImage: descriptor.icon)
            .font(TypographyTokens.caption2.weight(.semibold))
            .padding(.horizontal, SpacingTokens.xs2)
            .padding(.vertical, SpacingTokens.xxs2)
            .background(descriptor.background, in: Capsule())
            .foregroundColor(descriptor.foreground)
    }

    private func loadSourceDescriptor(for source: DiagramLoadSource) -> (text: String, icon: String, foreground: Color, background: Color) {
        switch source {
        case .live(let date):
            return (
                "Live · " + relativeTimeString(since: date),
                "bolt.fill",
                ColorTokens.Status.success.opacity(0.9),
                ColorTokens.Status.success.opacity(0.15)
            )
        case .cache(let date):
            return (
                "Cached · " + relativeTimeString(since: date),
                "clock.fill",
                ColorTokens.Text.secondary,
                ColorTokens.Text.primary.opacity(0.08)
            )
        }
    }

    private func relativeTimeString(since date: Date) -> String {
        EchoFormatters.relativeDate(date)
    }

}
