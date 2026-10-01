import SwiftUI

extension QueryStoreView {
    internal var queryStoreDisabledView: some View {
        VStack(spacing: 0) {
            ContentUnavailableView {
                Label("Query Store is off", systemImage: "chart.bar.xaxis")
            } description: {
                Text("Enable Query Store in Database Properties to start capturing query performance data.")
            } actions: {
                Button("Open Database Properties") {
                    openDatabaseProperties()
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, SpacingTokens.xxl)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    internal var filterBar: some View {
        HStack(spacing: SpacingTokens.md) {
            Picker("Time Range", selection: $viewModel.filterTimeRange) {
                ForEach(QueryStoreViewModel.TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .frame(width: 160)

            TextField("Filter query text", text: $viewModel.filterQueryText, prompt: Text("Search queries"))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 220)

            Stepper("Min Executions: \(viewModel.filterMinExecutions)", value: $viewModel.filterMinExecutions, in: 1...10000)
                .font(TypographyTokens.detail)

            Button {
                Task { await viewModel.refreshTopQueries() }
            } label: {
                Label("Apply", systemImage: "line.3.horizontal.decrease.circle")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.secondary)
    }

    internal var contentView: some View {
        VStack(spacing: 0) {
            if viewModel.selectedSection == .topQueries {
                filterBar
                Divider()
            }

            switch viewModel.selectedSection {
            case .topQueries:
                QueryStoreTopQueriesSection(
                    viewModel: viewModel,
                    onPopout: popout,
                    onOpenInQueryWindow: openInQueryWindow,
                    onDoubleClick: { appState.showInfoSidebar.toggle() }
                )
            case .regressedQueries:
                QueryStoreRegressedSection(
                    viewModel: viewModel,
                    onPopout: popout,
                    onOpenInQueryWindow: openInQueryWindow,
                    onDoubleClick: { appState.showInfoSidebar.toggle() }
                )
            }

            if viewModel.selectedQueryId != nil {
                Divider()
                QueryStorePlanDetailSection(viewModel: viewModel)
                    .frame(maxHeight: 220)

                if !viewModel.waitStats.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Wait Statistics")
                            .font(TypographyTokens.headline)
                            .padding(SpacingTokens.sm)
                        QueryStoreWaitStatsSection(waitStats: viewModel.waitStats)
                    }
                    .frame(maxHeight: 180)
                }
            }
        }
    }
}
