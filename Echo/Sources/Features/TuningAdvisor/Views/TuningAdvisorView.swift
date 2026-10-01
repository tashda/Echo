import SwiftUI
import SQLServerKit

struct TuningAdvisorView: View {
    @Bindable var viewModel: TuningAdvisorViewModel
    @State private var recommendationsFraction: CGFloat = 0.55

    var body: some View {
        // TT1: recommendations and their detail are two cards; the pages are in the tab (36.2)
        // and Refresh in the window toolbar (37.5).
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .adaptiveWorkspaceCard()
            .tabContentFrame()
            .tabToolbar(groups: [[.refresh(isBusy: viewModel.isRefreshing) { [viewModel] in viewModel.refreshSelectedTab() }]])
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
