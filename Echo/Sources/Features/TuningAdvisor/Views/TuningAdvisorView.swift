import SwiftUI
import SQLServerKit

struct TuningAdvisorView: View {
    @Bindable var viewModel: TuningAdvisorViewModel
    @Environment(ProjectStore.self) private var projectStore
    @State private var recommendationsFraction: CGFloat = 0.55

    var body: some View {
        // TT1: the toolbar on the canvas; recommendations and their detail are two cards.
        VStack(spacing: projectStore.globalSettings.workspaceGutter.points) {
            CenteredTabSectionToolbar {
                TabSectionPicker(
                    "Tuning Section",
                    selection: $viewModel.selectedTab,
                    itemCount: TuningAdvisorViewModel.TuningTab.allCases.count
                ) {
                    ForEach(TuningAdvisorViewModel.TuningTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
            } controls: {
                toolbarControls
            }
            .tabSectionToolbarOnCanvas()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .adaptiveWorkspaceCard()
        }
        .tabContentFrame()
        .onAppear {
            viewModel.refresh()
        }
        .onChange(of: viewModel.selectedTab) { _, newTab in
            let hasLoaded = switch newTab {
            case .missingIndexes: viewModel.hasLoadedRecommendations
            case .indexUsage: viewModel.hasLoadedIndexUsage
            }
            if !hasLoaded {
                viewModel.refreshSelectedTab()
            }
        }
    }

    private var toolbarControls: some View {
        TabRefreshButton(isRefreshing: viewModel.isRefreshing) {
            viewModel.refreshSelectedTab()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.selectedTab {
        case .missingIndexes:
            if !viewModel.hasLoadedRecommendations {
                initialState(title: "Loading Recommendations")
            } else if viewModel.recommendations.isEmpty {
                emptyState
            } else {
                CardSplitView(axis: .vertical, fraction: $recommendationsFraction, minFraction: 0.25) {
                    recommendationTable
                } second: {
                    recommendationDetailView
                }
            }
        case .indexUsage:
            if !viewModel.hasLoadedIndexUsage {
                initialState(title: "Loading Index Usage")
            } else {
                IndexUsageSection(stats: viewModel.indexUsageStats)
            }
        }
    }

    @ViewBuilder
    private func initialState(title: String) -> some View {
        if let error = viewModel.loadErrorMessage, !viewModel.isRefreshing {
            TabContentUnavailableView("Could Not Load Tuning Data", systemImage: "exclamationmark.triangle") {
                Text(error)
            } actions: {
                Button("Try Again") { viewModel.refreshSelectedTab() }
                    .buttonStyle(.bordered)
            }
        } else {
            TabInitializingPlaceholder(
                icon: "wand.and.sparkles",
                title: title,
                subtitle: "Analyzing SQL Server performance data…"
            )
        }
    }
}
