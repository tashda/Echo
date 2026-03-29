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

    func openSchemaDiffFromDiagram() {
        guard let context = viewModel.context,
              let session = environmentState.sessionGroup.activeSessions.first(where: { $0.id == context.connectionSessionID }) else {
            return
        }

        let tab = session.addSchemaDiffTab()
        if let schemaDiff = tab.schemaDiffVM {
            let resolved = SchemaDiffViewModel.resolvedSchemas(
                availableSchemas: schemaDiff.availableSchemas,
                preferredSource: context.object.schema,
                currentSource: context.object.schema,
                currentTarget: schemaDiff.targetSchema
            )
            schemaDiff.sourceSchema = resolved.source
            schemaDiff.targetSchema = resolved.target
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
