import SwiftUI
import EchoSense
#if os(macOS)
import AppKit
#endif

struct WorkspaceContentView: View {
    @ObservedObject var tab: WorkspaceTab
    let runQuery: (String) async -> Void
    let cancelQuery: () -> Void
    let gridStateProvider: () -> QueryResultsGridState
    @EnvironmentObject private var appearanceStore: AppearanceStore

    var body: some View {
        ZStack {
            ColorTokens.Background.primary
                .ignoresSafeArea()

            Group {
                if let structureEditor = tab.structureEditor {
                    TableStructureEditorView(tab: tab, viewModel: structureEditor)
                        .background(ColorTokens.Background.primary)
                } else if let diagram = tab.diagram {
                    SchemaDiagramView(viewModel: diagram)
                        .background(ColorTokens.Background.primary)
                } else if let jobs = tab.jobQueue {
                    JobQueueView(viewModel: jobs)
                        .background(ColorTokens.Background.primary)
                } else if let query = tab.query {
                    QueryEditorContainer(
                        tab: tab,
                        query: query,
                        runQuery: runQuery,
                        cancelQuery: cancelQuery,
                        gridStateProvider: gridStateProvider
                    )
                } else {
                    EmptyView()
                }
            }
        }
    }
}
