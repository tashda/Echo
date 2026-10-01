import SwiftUI
import SQLServerKit

/// Availability Groups' header line (round 37.2): the selected group's backup preference. Failover
/// and Refresh are in the window toolbar (round 37.5, `toolbarGroups`).
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
    }

    /// Failover (for the selected group) and Refresh.
    @MainActor
    static func toolbarGroups(_ viewModel: AvailabilityGroupsViewModel) -> [[TabToolbarItem]] {
        var items: [TabToolbarItem] = []
        if viewModel.selectedGroup != nil {
            items.append(TabToolbarItem(id: "failover", title: "Fail over the selected availability group", symbol: "arrow.triangle.2.circlepath",
                                        isDisabled: viewModel.isFailoverInProgress) {
                if let name = viewModel.selectedGroup?.name { viewModel.requestFailover(groupName: name) }
            })
        }
        items.append(.refresh(isBusy: viewModel.loadingState == .loading) { Task { await viewModel.refresh() } })
        return [items]
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
