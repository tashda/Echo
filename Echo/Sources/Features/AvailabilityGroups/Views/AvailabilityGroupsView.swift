import SwiftUI
import SQLServerKit

struct AvailabilityGroupsView: View {
    @Bindable var viewModel: AvailabilityGroupsViewModel

    var body: some View {
        VStack(spacing: 0) {
            AvailabilityGroupsToolbar(viewModel: viewModel)

            if viewModel.loadingState == .loading && viewModel.groups.isEmpty {
                loadingPlaceholder
            } else if case .error(let message) = viewModel.loadingState,
                      viewModel.groups.isEmpty {
                errorPlaceholder(message)
            } else if !viewModel.isHadrEnabled {
                hadrDisabledPlaceholder
            } else {
                contentView
            }
        }
        .background(ColorTokens.Background.primary)
        .task {
            await viewModel.loadAll()
        }
        .alert(
            "Confirm Failover",
            isPresented: $viewModel.showFailoverConfirmation
        ) {
            Button("Cancel", role: .cancel) {
                viewModel.failoverGroupName = nil
            }
            Button("Failover", role: .destructive) {
                Task { await viewModel.performFailover() }
            }
            .disabled(viewModel.isFailoverInProgress)
        } message: {
            if let name = viewModel.failoverGroupName {
                Text("This will initiate a manual failover for availability group \"\(name)\". This operation may cause brief downtime.")
            }
        }
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView()
            Text("Loading Availability Groups...")
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
            Text("Could not load Availability Groups")
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

    private var hadrDisabledPlaceholder: some View {
        VStack(spacing: SpacingTokens.md) {
            Image(systemName: "server.rack")
                .font(.title2)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("Always On is not enabled")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)
            Text("HADR (High Availability Disaster Recovery) is not enabled on this server.")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.groups.isEmpty {
            VStack(spacing: SpacingTokens.md) {
                Image(systemName: "server.rack")
                    .font(.title2)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                Text("No Availability Groups")
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.primary)
                Text("HADR is enabled but no availability groups are configured.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                    AGGroupPicker(viewModel: viewModel)
                    AGReplicaSection(replicas: viewModel.replicas, detailState: viewModel.detailLoadingState)
                    AGDatabaseSection(databases: viewModel.databases, detailState: viewModel.detailLoadingState)
                }
                .padding(SpacingTokens.lg)
            }
        }
    }
}
