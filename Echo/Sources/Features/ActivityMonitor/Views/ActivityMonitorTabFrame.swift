import SwiftUI

/// Shared container for all activity monitor views. Provides the toolbar, loading/permission states,
/// sparkline + section content layout, and SQL inspector sheet — so each database-specific activity
/// monitor only needs to supply its section picker, sparklines, section content, and onChange handlers.
struct ActivityMonitorTabFrame<SectionPicker: View, Sparklines: View, SectionContent: View>: View {
    @Bindable var viewModel: ActivityMonitorViewModel
    let hasPermission: Bool
    let hasSnapshot: Bool
    @Binding var selectedSQLContext: SQLPopoutContext?
    let onOpenInQueryWindow: (_ sql: String, _ database: String?) -> Void
    @ViewBuilder let sectionPicker: () -> SectionPicker
    @ViewBuilder let sparklines: () -> Sparklines
    @ViewBuilder let sectionContent: () -> SectionContent

    var body: some View {
        VStack(spacing: 0) {
            TabSectionToolbar { sectionPicker() }

            if !hasPermission {
                permissionDeniedView
            } else if !hasSnapshot {
                loadingView
            } else {
                VStack(spacing: 0) {
                    sparklines()
                    Divider()
                    sectionContent()
                }
            }
        }
        .background(ColorTokens.Background.primary)
        .sheet(item: $selectedSQLContext) { context in
            SQLInspectorPopover(context: context) { sql, database in
                onOpenInQueryWindow(sql, database)
            }
        }
    }

    private var permissionDeniedView: some View {
        ContentUnavailableView {
            Label("Insufficient Permissions", systemImage: "lock.shield")
        } description: {
            Text("Activity Monitor requires VIEW SERVER STATE permission on this server. Contact your database administrator to grant access.")
        }
    }

    private var loadingView: some View {
        TabInitializingPlaceholder(
            icon: "gauge.with.dots.needle.33percent",
            title: "Initializing Activity Monitor",
            subtitle: "Waiting for the first snapshot\u{2026}"
        )
    }
}
