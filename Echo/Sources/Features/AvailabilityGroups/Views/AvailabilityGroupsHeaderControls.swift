import SwiftUI
import SQLServerKit

/// Availability Groups' controls on the tool's header line (round 37.2, 37.3): the selected
/// group's backup preference, then Failover and Refresh.
struct AvailabilityGroupsHeaderControls: View {
    @Bindable var viewModel: AvailabilityGroupsViewModel

    private static let backupPreferences = ["PRIMARY", "SECONDARY_ONLY", "SECONDARY", "NONE"]

    var body: some View {
        if let group = viewModel.selectedGroup {
            ToolTabPickerPill(
                title: "Backup Preference",
                systemImage: "externaldrive",
                selection: Binding(
                    get: { group.automatedBackupPreference },
                    set: { newValue in
                        Task { await viewModel.setBackupPreference(groupName: group.name, preference: newValue) }
                    }
                ),
                options: Self.backupPreferences,
                label: Self.preferenceTitle
            )
        }
        ToolTabActionGroup {
            if let group = viewModel.selectedGroup {
                ToolTabActionButton(title: "Fail over the selected availability group", systemImage: "arrow.triangle.2.circlepath",
                                    isDisabled: viewModel.isFailoverInProgress) {
                    viewModel.requestFailover(groupName: group.name)
                }
            }
            ToolTabRefreshButton(isRefreshing: viewModel.loadingState == .loading) {
                Task { await viewModel.refresh() }
            }
        }
    }

    static func preferenceTitle(_ value: String) -> String {
        switch value {
        case "PRIMARY": "Primary"
        case "SECONDARY_ONLY": "Secondary Only"
        case "SECONDARY": "Prefer Secondary"
        case "NONE": "Any Replica"
        default: value
        }
    }
}
