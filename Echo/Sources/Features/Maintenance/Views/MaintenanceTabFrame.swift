import SwiftUI

/// Shared container for all maintenance views. Wraps `TabContentWithPanel` with a section toolbar,
/// loading placeholder, execution console, and status bar — so each database-specific maintenance
/// view only needs to supply its section content. Panes are cards (TT1). A tool whose sections are
/// pages in its tab (round 36.2) has no toolbar row; the others still pass their row's content.
struct MaintenanceTabFrame<SectionPicker: View, Content: View>: View {
    @Bindable var panelState: BottomPanelState
    let serverName: String
    let isInitialized: Bool
    var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble?
    @ViewBuilder let sectionPicker: () -> SectionPicker
    @ViewBuilder let content: () -> Content

    @Environment(ProjectStore.self) private var projectStore

    init(
        panelState: BottomPanelState,
        serverName: String,
        isInitialized: Bool,
        statusBubble: BottomPanelStatusBarConfiguration.StatusBubble? = nil,
        @ViewBuilder sectionPicker: @escaping () -> SectionPicker,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.panelState = panelState
        self.serverName = serverName
        self.isInitialized = isInitialized
        self.statusBubble = statusBubble
        self.sectionPicker = sectionPicker
        self.content = content
    }

    var body: some View {
        // TT1: the section toolbar sits on the canvas above the cards; the section is one card,
        // or its own cards when it has several panes, with the Messages panel below.
        VStack(spacing: projectStore.globalSettings.workspaceGutter.points) {
            if isInitialized, SectionPicker.self != EmptyView.self {
                CenteredTabSectionToolbar { sectionPicker() }
                    .tabSectionToolbarOnCanvas()
            }
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
                    content()
                }
            } panelContent: {
                ExecutionConsoleView(executionMessages: panelState.messages) {
                    panelState.clearMessages()
                }
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

extension MaintenanceTabFrame where SectionPicker == EmptyView {
    /// A tool whose sections are pages in its tab: no toolbar row above the content.
    init(
        panelState: BottomPanelState,
        serverName: String,
        isInitialized: Bool,
        statusBubble: BottomPanelStatusBarConfiguration.StatusBubble? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(panelState: panelState, serverName: serverName, isInitialized: isInitialized,
                  statusBubble: statusBubble, sectionPicker: { EmptyView() }, content: content)
    }
}
