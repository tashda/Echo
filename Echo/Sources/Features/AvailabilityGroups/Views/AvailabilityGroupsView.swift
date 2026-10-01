import SwiftUI
import SQLServerKit

struct AvailabilityGroupsView: View {
    @Bindable var viewModel: AvailabilityGroupsViewModel

    var body: some View {
        VStack(spacing: 0) {
            AvailabilityGroupsToolbar(viewModel: viewModel)
            Divider()

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
        .tabContentFrame()
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
        TabInitializingPlaceholder(
            icon: "server.rack",
            title: "Loading Availability Groups",
            subtitle: "Fetching availability group data…"
        )
    }

    private func errorPlaceholder(_ message: String) -> some View {
        TabContentUnavailableView("Could Not Load Availability Groups", systemImage: "exclamationmark.triangle") {
            Text(message)
        } actions: {
            Button("Try Again") { Task { await viewModel.refresh() } }
                .buttonStyle(.bordered)
        }
    }

    private var hadrDisabledPlaceholder: some View {
        TabContentUnavailableView("Always On Is Not Enabled", systemImage: "server.rack") {
            Text("HADR (High Availability Disaster Recovery) is not enabled on this server.")
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.groups.isEmpty {
            TabContentUnavailableView("No Availability Groups", systemImage: "server.rack") {
                Text("HADR is enabled but no availability groups are configured.")
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                    AGGroupPicker(viewModel: viewModel)
                    AGReplicaSection(replicas: viewModel.replicas, detailState: viewModel.detailLoadingState)
                    AGDatabaseSection(
                        databases: viewModel.databases,
                        detailState: viewModel.detailLoadingState,
                        groupName: viewModel.selectedGroup?.name,
                        onRemoveDatabase: { dbName in
                            if let groupName = viewModel.selectedGroup?.name {
                                Task { await viewModel.removeDatabase(groupName: groupName, databaseName: dbName) }
                            }
                        }
                    )
                    AGListenerSection(listeners: viewModel.listeners, detailState: viewModel.detailLoadingState)
                }
                .padding(SpacingTokens.lg)
            }
        }
    }
}
