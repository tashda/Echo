import SwiftUI
import SQLServerKit

struct QueryStoreView: View {
    @Bindable var viewModel: QueryStoreViewModel

    var body: some View {
        VStack(spacing: 0) {
            QueryStoreToolbar(viewModel: viewModel)

            if viewModel.loadingState == .loading && viewModel.storeOptions == nil {
                loadingPlaceholder
            } else if case .error(let message) = viewModel.loadingState,
                      viewModel.storeOptions == nil {
                errorPlaceholder(message)
            } else {
                contentView
            }
        }
        .background(ColorTokens.Background.primary)
        .task {
            await viewModel.loadAll()
        }
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView()
            Text("Loading Query Store data...")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorPlaceholder(_ message: String) -> some View {
        VStack(spacing: SpacingTokens.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(ColorTokens.Status.warning)
            Text("Could not load Query Store")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)
            Text(message)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.xl) {
                if let options = viewModel.storeOptions {
                    QueryStoreStatusBar(options: options)
                }

                switch viewModel.selectedSection {
                case .topQueries:
                    QueryStoreTopQueriesSection(viewModel: viewModel)
                case .regressedQueries:
                    QueryStoreRegressedSection(viewModel: viewModel)
                }

                if viewModel.selectedQueryId != nil {
                    QueryStorePlanDetailSection(viewModel: viewModel)
                }
            }
            .padding(SpacingTokens.lg)
        }
    }
}
