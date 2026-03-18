import SwiftUI
import SQLServerKit

struct ExtendedEventsView: View {
    @Bindable var viewModel: ExtendedEventsViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.loadingState == .loading && viewModel.sessions.isEmpty {
                loadingPlaceholder
            } else if case .error(let message) = viewModel.loadingState,
                      viewModel.sessions.isEmpty {
                errorPlaceholder(message)
            } else {
                contentView
            }
        }
        .background(ColorTokens.Background.primary)
        .task {
            await viewModel.loadSessions()
        }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            ExtendedEventsCreateSheet(viewModel: viewModel)
        }
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView()
            Text("Loading Extended Events sessions...")
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
            Text("Could not load Extended Events")
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
        Group {
            switch viewModel.selectedSection {
            case .sessions:
                ExtendedEventsSessionList(viewModel: viewModel)
            case .liveData:
                ExtendedEventsDataView(viewModel: viewModel)
            }
        }
    }
}
