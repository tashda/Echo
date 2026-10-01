import SwiftUI
import SQLServerKit

struct PolicyManagementView: View {
    @Bindable var viewModel: PolicyManagementViewModel
    @State private var listFraction: CGFloat = 0.64
    
    var body: some View {
        // Its pages are in the tab (round 36.2); Refresh in the window toolbar (37.5).
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorTokens.Background.primary)
            .tabToolbar(groups: [[.refresh(isBusy: viewModel.isRefreshing) { [viewModel] in viewModel.refresh() }]])
        .tabContentFrame()
        .onAppear {
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
                    // Manage (round 37.4, MA0): the selected policy's details on a card beside the list.
                    CardSplitView(axis: .horizontal, fraction: $listFraction, minFraction: 0.4, maxFraction: 0.8) {
                        policiesTable
                    } second: {
                        PolicyDetailsPane(viewModel: viewModel)
                    }
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
