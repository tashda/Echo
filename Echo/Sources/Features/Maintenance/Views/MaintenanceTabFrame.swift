import SwiftUI

/// Shared container for all maintenance views. Wraps `TabContentWithPanel` with a section toolbar,
/// loading placeholder, execution console, and status bar — so each database-specific maintenance
/// view only needs to supply its section picker and section content.
struct MaintenanceTabFrame<SectionPicker: View, Content: View>: View {
    @Bindable var panelState: BottomPanelState
    let connectionText: String
    let isInitialized: Bool
    var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble?
    @ViewBuilder let sectionPicker: () -> SectionPicker
    @ViewBuilder let content: () -> Content

    var body: some View {
        TabContentWithPanel(
            panelState: panelState,
            statusBarConfiguration: statusBarConfig
        ) {
            if !isInitialized {
                TabInitializingPlaceholder(
                    icon: "wrench.and.screwdriver",
                    title: "Initializing Maintenance",
                    subtitle: "Loading database health data\u{2026}"
                )
            } else {
                VStack(spacing: 0) {
                    TabSectionToolbar { sectionPicker() }
                    Divider()
                    content()
                }
            }
        } panelContent: {
            ExecutionConsoleView(executionMessages: panelState.messages) {
                panelState.clearMessages()
            }
        }
    }

    private var statusBarConfig: BottomPanelStatusBarConfiguration {
        var config = BottomPanelStatusBarConfiguration(
            connectionText: connectionText,
            availableSegments: panelState.availableSegments,
            selectedSegment: panelState.selectedSegment,
            onSelectSegment: { segment in
                if panelState.isOpen && panelState.selectedSegment == segment {
                    panelState.isOpen = false
                } else {
                    panelState.selectedSegment = segment
                    if !panelState.isOpen { panelState.isOpen = true }
                }
            },
            onTogglePanel: { panelState.isOpen.toggle() },
            isPanelOpen: panelState.isOpen
        )
        config.statusBubble = statusBubble
        return config
    }
}
