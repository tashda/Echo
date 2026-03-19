import SwiftUI

struct ExtendedEventsToolbar: View {
    @Bindable var viewModel: ExtendedEventsViewModel

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            Spacer()
            createButton
            refreshButton
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.secondary.opacity(0.5))
    }

    private var createButton: some View {
        Button {
            viewModel.showCreateSheet = true
        } label: {
            Label("New Session", systemImage: "plus")
                .font(TypographyTokens.detail)
        }
        .buttonStyle(.borderless)
    }

    private var refreshButton: some View {
        Button {
            Task {
                await viewModel.loadSessions()
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .font(TypographyTokens.detail)
        }
        .buttonStyle(.borderless)
        .disabled(viewModel.loadingState == .loading)
    }
}
