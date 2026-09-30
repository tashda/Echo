import SwiftUI

/// Shared container for all maintenance views. Wraps `TabContentWithPanel` with a section toolbar,
/// loading placeholder, execution console, and status bar — so each database-specific maintenance
/// view only needs to supply its section picker and section content. Panes are cards (TT1).
struct MaintenanceTabFrame<SectionPicker: View, Content: View>: View {
    @Bindable var panelState: BottomPanelState
    let serverName: String
    let isInitialized: Bool
    var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble?
    @ViewBuilder let sectionPicker: () -> SectionPicker
    @ViewBuilder let content: () -> Content

    @Environment(ProjectStore.self) private var projectStore

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
                // TT1: the section toolbar sits on the canvas; the section is one card, or its
                // own cards when it has several panes.
                VStack(spacing: projectStore.globalSettings.workspaceGutter.points) {
                    CenteredTabSectionToolbar { sectionPicker() }
                        .tabSectionToolbarOnCanvas()
                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .adaptiveWorkspaceCard()
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
            serverName: serverName,
            databaseName: nil,
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
