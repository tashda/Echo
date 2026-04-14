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
    @Environment(DiagramBuilder.self) var diagramBuilder
    @Environment(EnvironmentState.self) var environmentState

    @Environment(AppearanceStore.self) var appearanceStore

    @State internal var zoom: CGFloat = 1.0
    @State internal var contentOffset: CGSize = .zero
    @State internal var lastDragOffset: CGSize = .zero
    @State internal var hasCenteredDiagram = false
    @State internal var isDraggingNode = false
    @State private var persistTask: Task<Void, Never>?
    @State internal var isRefreshing = false
    @State private var lastKnownNodeCount: Int = 0
    @State private var lastLoadingState: Bool = false
    @State internal var viewSize: CGSize = .zero
    @State internal var diagramSearchText: String = ""
    @State internal var showRelationships: Bool = true
    @State internal var showIndexes: Bool = true

    internal let minZoom: CGFloat = 0.4
    internal let maxZoom: CGFloat = 2.5

    var body: some View {
        if viewModel.isLoading && viewModel.nodes.isEmpty {
            loadingPlaceholder
        } else if let error = viewModel.errorMessage {
            errorPlaceholder(error)
        } else {
            diagramContent
        }
    }

    @ViewBuilder
    private var loadingPlaceholder: some View {
        TabInitializingPlaceholder(
            icon: "rectangle.connected.to.line.below",
            title: "Loading Diagram",
            subtitle: viewModel.statusMessage ?? "Fetching structure and relationships\u{2026}"
        )
    }

    @ViewBuilder
    private func errorPlaceholder(_ error: String) -> some View {
        VStack(spacing: SpacingTokens.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(ColorTokens.Status.error)
            VStack(spacing: SpacingTokens.xxs) {
                Text("Unable to Load Diagram")
                    .font(TypographyTokens.standard.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.secondary)
                Text(error)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var diagramContent: some View {
        GeometryReader { geometry in
            let shouldRenderEdges: Bool = {
                guard showRelationships else { return false }
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
                    showIndexes: showIndexes,
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
            .overlay {
                if let message = viewModel.statusMessage, !message.isEmpty {
                    DiagramBannerStatus(message: message, showsProgress: viewModel.isLoading, palette: palette)
                }
            }
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

    func openForwardEngineeringSQL() {
        guard let context = viewModel.context,
              let session = environmentState.sessionGroup.activeSessions.first(where: { $0.id == context.connectionSessionID }) else {
            return
        }

        let sql = SchemaDiagramForwardEngineeringPlan.sql(
            title: viewModel.title,
            nodes: viewModel.nodes,
            edges: viewModel.edges
        )
        let database = SchemaDiagramForwardEngineeringPlan.targetDatabase(
            for: session.connection.databaseType,
            context: context,
            fallbackDatabase: session.connection.database
        )
        environmentState.openQueryTab(for: session, presetQuery: sql, database: database)
    }

    func applyForwardEngineeringSQL() {
        guard let context = viewModel.context,
              let session = environmentState.sessionGroup.activeSessions.first(where: { $0.id == context.connectionSessionID }) else {
            return
        }

        let sql = SchemaDiagramForwardEngineeringPlan.sql(
            title: viewModel.title,
            nodes: viewModel.nodes,
            edges: viewModel.edges
        )
        let database = SchemaDiagramForwardEngineeringPlan.targetDatabase(
            for: session.connection.databaseType,
            context: context,
            fallbackDatabase: session.connection.database
        )
        environmentState.openQueryTab(
            for: session,
            presetQuery: sql,
            autoExecute: true,
            database: database
        )
    }
}
