import SwiftUI

struct PostgresExtensionsView: View {
    @Bindable var tab: WorkspaceTab
    @Bindable var viewModel: PostgresExtensionsViewModel

    @Environment(EnvironmentState.self) var environmentState
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading extensions\u{2026}")
                    Spacer()
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: SpacingTokens.md) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(TypographyTokens.hero)
                        .foregroundStyle(ColorTokens.Status.warning)
                    Text(error)
                        .font(TypographyTokens.standard)
                    Button("Retry") {
                        Task { await viewModel.reload() }
                    }
                    Spacer()
                }
            } else {
                content
            }
        }
        .background(ColorTokens.Background.primary)
        .task {
            await viewModel.reload()
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: SpacingTokens.sm) {
                Image(systemName: "puzzlepiece")
                    .font(TypographyTokens.hero)
                    .foregroundStyle(ColorTokens.Status.info)
                
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    Text("Extension Manager")
                        .font(TypographyTokens.standard.weight(.bold))
                    
                    Text(viewModel.databaseName)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                
                Spacer()

                Button(action: { Task { await viewModel.reload() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .font(TypographyTokens.detail)
            }
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.top, SpacingTokens.lg)

            CenteredTabSectionToolbar {
                TabSectionPicker(
                    "Extension Section",
                    selection: $viewModel.selectedTab,
                    itemCount: PostgresExtensionsViewModel.Tab.allCases.count
                ) {
                    ForEach(PostgresExtensionsViewModel.Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
            }
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ColorTokens.Text.tertiary)
                TextField("Search extensions\u{2026}", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(SpacingTokens.xs)
            .background(ColorTokens.Text.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.xs))
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.bottom, SpacingTokens.lg)
        }
        .background(ColorTokens.Background.secondary.opacity(0.5))
    }
    
    var content: some View {
        Group {
            if viewModel.selectedTab == .installed {
                installedList
            } else {
                marketplaceList
            }
        }
    }
}
