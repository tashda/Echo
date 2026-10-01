import SwiftUI
import SQLServerKit

struct AvailabilityGroupsToolbar: View {
    @Bindable var viewModel: AvailabilityGroupsViewModel

    var body: some View {
        TabSectionToolbar {
            hadrBadge
        } controls: {
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
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 180)
                .help("Choose the automated backup preference")

                Button {
                    viewModel.requestFailover(groupName: group.name)
                } label: {
                    Label("Failover", systemImage: "arrow.triangle.2.circlepath")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(viewModel.isFailoverInProgress)
                .help("Fail over the selected availability group")
            }

            TabRefreshButton(isRefreshing: viewModel.loadingState == .loading) {
                Task { await viewModel.refresh() }
            }
        }
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
                .help(enabled ? "Always On is enabled" : "Always On is disabled")
        }
    }
}
