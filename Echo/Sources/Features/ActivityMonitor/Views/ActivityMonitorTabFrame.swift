import SwiftUI

/// Shared container for all activity monitor views. Provides the toolbar, loading/permission states,
/// sparkline + section content layout, and SQL inspector sheet — so each database-specific activity
/// monitor only needs to supply its sparklines, section content, and onChange handlers. Its pages are
/// chosen in the tab (ST2).
struct ActivityMonitorTabFrame<Sparklines: View, SectionContent: View>: View {
    @Bindable var viewModel: ActivityMonitorViewModel
    let hasPermission: Bool
    let hasSnapshot: Bool
    @Binding var selectedSQLContext: SQLPopoutContext?
    let onOpenInQueryWindow: (_ sql: String, _ database: String?) -> Void
    @ViewBuilder let sparklines: () -> Sparklines
    @ViewBuilder let sectionContent: () -> SectionContent

    var body: some View {
        // The pages are in the tab itself (ST2), so the frame starts with the content.
        VStack(spacing: 0) {
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
        .tabContentFrame()
        .sheet(item: $selectedSQLContext) { context in
            SQLInspectorSheet(context: context) { sql, database in
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
