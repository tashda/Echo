import SwiftUI
import SQLServerKit

struct PolicyManagementView: View {
    @Bindable var viewModel: PolicyManagementViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            CenteredTabSectionToolbar {
                TabSectionPicker(
                    "Policy Section",
                    selection: $viewModel.selectedTab,
                    itemCount: PolicyManagementViewModel.PolicyTab.allCases.count
                ) {
                    ForEach(PolicyManagementViewModel.PolicyTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
            } controls: {
                toolbarControls
            }
            Divider()

            content
        }
        .background(ColorTokens.Background.primary)
        .tabContentFrame()
        .onAppear {
            viewModel.refresh()
        }
    }

    private var toolbarControls: some View {
        TabRefreshButton(isRefreshing: viewModel.isRefreshing) {
            viewModel.refresh()
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            initialState
        } else {
            switch viewModel.selectedTab {
            case .policies:
                if viewModel.policies.isEmpty {
                    emptyState("No Policies", systemImage: "checklist", description: "No Policy-Based Management policies are configured on this server.")
                } else {
                    policiesTable
                }
            case .conditions:
                if viewModel.conditions.isEmpty {
                    emptyState("No Conditions", systemImage: "line.3.horizontal.decrease.circle", description: "No policy conditions are configured on this server.")
                } else {
                    conditionsTable
                }
            case .facets:
                if viewModel.facets.isEmpty {
                    emptyState("No Facets", systemImage: "square.grid.2x2", description: "SQL Server did not return any policy facets.")
                } else {
                    facetsTable
                }
            case .history:
                if viewModel.history.isEmpty {
                    emptyState("No Policy History", systemImage: "clock.arrow.circlepath", description: "No policy evaluation history has been recorded.")
                } else {
                    historyTable
                }
            }
        }
    }

    @ViewBuilder
    private var initialState: some View {
        if let error = viewModel.loadErrorMessage, !viewModel.isRefreshing {
            TabContentUnavailableView("Could Not Load Policies", systemImage: "exclamationmark.triangle") {
                Text(error)
            } actions: {
                Button("Try Again") { viewModel.refresh() }
                    .buttonStyle(.bordered)
            }
        } else {
            TabInitializingPlaceholder(
                icon: "checklist",
                title: "Loading Policy Management",
                subtitle: "Fetching policies, conditions, facets, and history…"
            )
        }
    }

    private func emptyState(
        _ title: LocalizedStringKey,
        systemImage: String,
        description: LocalizedStringKey
    ) -> some View {
        TabContentUnavailableView(title, systemImage: systemImage) {
            Text(description)
        }
    }
    
}
