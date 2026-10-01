import SwiftUI

struct PostgresExtensionsView: View {
    @Bindable var tab: WorkspaceTab
    @Bindable var viewModel: PostgresExtensionsViewModel

    @Environment(EnvironmentState.self) var environmentState
    
    var body: some View {
        // Installed and Marketplace are pages in the tab (round 36.2); search on the header line
        // (37.2), Refresh in the window toolbar (37.5).
        VStack(spacing: 0) {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Background.primary)
        .toolTabHeaderControls {
            ToolTabSearchField(prompt: "Search extensions", text: $viewModel.searchText)
        }
        .tabToolbar(groups: [[.refresh(isBusy: viewModel.isLoading) { [viewModel] in Task { await viewModel.reload() } }]])
        .task {
            await viewModel.reload()
        }
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
