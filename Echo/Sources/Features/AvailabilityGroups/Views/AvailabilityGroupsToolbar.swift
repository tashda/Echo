import SwiftUI
import SQLServerKit

struct AvailabilityGroupsToolbar: View {
    @Bindable var viewModel: AvailabilityGroupsViewModel

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: "server.rack")
                .foregroundStyle(ColorTokens.Text.secondary)

            Text("Availability Groups")
                .font(TypographyTokens.prominent.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)

            hadrBadge

            Spacer()

            if let group = viewModel.selectedGroup {
                Picker("Backup Preference", selection: Binding(
                    get: { group.automatedBackupPreference },
                    set: { newValue in
                        Task { await viewModel.setBackupPreference(groupName: group.name, preference: newValue) }
                    }
                )) {
                    Text("Primary").tag("PRIMARY")
                    Text("Secondary Only").tag("SECONDARY_ONLY")
                    Text("Prefer Secondary").tag("SECONDARY")
                    Text("Any Replica").tag("NONE")
                }
                .frame(width: 180)

                Button {
                    viewModel.requestFailover(groupName: group.name)
                } label: {
                    Label("Failover", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(viewModel.isFailoverInProgress)
            }

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.loadingState == .loading)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
        .background(ColorTokens.Background.secondary)
    }

    @ViewBuilder
    private var hadrBadge: some View {
        if viewModel.loadingState == .loaded {
            let enabled = viewModel.isHadrEnabled
            Text(enabled ? "Enabled" : "Disabled")
                .font(TypographyTokens.detail.weight(.semibold))
                .padding(.horizontal, SpacingTokens.xs)
                .padding(.vertical, SpacingTokens.xxs)
                .background(
                    Capsule(style: .continuous)
                        .fill((enabled ? ColorTokens.Status.success : ColorTokens.Text.tertiary).opacity(0.15))
                )
                .foregroundStyle(enabled ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
        }
    }
}
