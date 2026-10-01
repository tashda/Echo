import SwiftUI
import SQLServerKit

struct ExtendedEventsView: View {
    var viewModel: ExtendedEventsViewModel
    var panelState: BottomPanelState
    let onPopout: ((String) -> Void)?
    var onDoubleClick: (() -> Void)?
    
    @Environment(TabStore.self) var tabStore
    
    @Environment(\.workspaceTab) var hostTab
    @Environment(ProjectStore.self) private var projectStore

    init(
        viewModel: ExtendedEventsViewModel,
        panelState: BottomPanelState,
        onPopout: ((String) -> Void)? = nil,
        onDoubleClick: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.panelState = panelState
        self.onPopout = onPopout
        self.onDoubleClick = onDoubleClick
    }

    var isWatchingLiveData: Bool {
        panelState.isOpen && panelState.selectedSegment == .liveData
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var panelState = panelState
        
        // A Monitor (round 37.4): the figures as tiles, then the sessions and their details as
        // cards with the Live Data and Messages panel below (TT1); the controls on the header
        // line (37.2, 37.3).
        VStack(spacing: projectStore.globalSettings.workspaceGutter.points) {
            if hasSessionsLoaded {
                ActivityMonitorSparklineStrip(metrics: ExtendedEventsFigures.metrics(sessions: viewModel.sessions, events: viewModel.eventData))
            }
            TabContentWithPanel(
                panelState: panelState,
                statusBarConfiguration: statusBarConfig
            ) {
                mainContent
            } panelContent: {
                panelContentView
            }
        }
        .tabToolbar(special: hasSessionsLoaded ? newSessionItem : nil, groups: hasSessionsLoaded ? [[watchLiveDataItem]] : [])
        .toolTabHeaderDetail(viewModel.sessions.isEmpty ? nil : "\(viewModel.sessions.count) sessions")
        .task {
            await viewModel.loadSessions()
        }
        .onChange(of: viewModel.selectedSessionName) { _, _ in
            if isWatchingLiveData {
                Task { await viewModel.loadEventData() }
            }
        }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            ExtendedEventsCreateSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showEditSheet) {
            ExtendedEventsEditSheet(viewModel: viewModel)
        }
        .tabContentFrame()
    }

    /// The sessions are in (or failed with some already shown), so the toolbar applies.
    private var hasSessionsLoaded: Bool {
        if viewModel.loadingState == .loading && viewModel.sessions.isEmpty { return false }
        if case .error = viewModel.loadingState, viewModel.sessions.isEmpty { return false }
        return true
    }

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.loadingState == .loading && viewModel.sessions.isEmpty {
            loadingPlaceholder
        } else if case .error(let message) = viewModel.loadingState,
                  viewModel.sessions.isEmpty {
            errorPlaceholder(message)
        } else if viewModel.sessions.isEmpty {
            TabContentUnavailableView("No Extended Events Sessions", systemImage: "waveform.path.ecg") {
                Text("Create a session to capture and inspect SQL Server events.")
            } actions: {
                Button("New Session") { viewModel.showCreateSheet = true }
                    .buttonStyle(.bordered)
            }
        } else {
            ExtendedEventsSessionList(viewModel: viewModel) { sessionName in
                viewModel.selectedSessionName = sessionName
                panelState.selectedSegment = .liveData
                panelState.isOpen = true
                Task { await viewModel.loadEventData() }
            }
        }
    }

    /// Round 37.5: New Session is the special button, Watch Live Data the group.
    private var newSessionItem: TabToolbarItem {
        TabToolbarItem(id: "newSession", title: "New Session", symbol: "waveform.badge.plus") { [viewModel] in viewModel.showCreateSheet = true }
    }

    private var watchLiveDataItem: TabToolbarItem {
        let canWatch = viewModel.sessions.first(where: { $0.name == viewModel.selectedSessionName })?.isRunning == true
        return TabToolbarItem(id: "watchLiveData",
                              title: canWatch || isWatchingLiveData ? "Watch Live Data" : "Select a running session to watch live data",
                              symbol: "waveform.path.ecg", isDisabled: !canWatch && !isWatchingLiveData, isOn: isWatchingLiveData, isToggle: true) { [viewModel, panelState] in
            if panelState.isOpen && panelState.selectedSegment == .liveData {
                panelState.isOpen = false
            } else {
                panelState.selectedSegment = .liveData
                panelState.isOpen = true
                Task { await viewModel.loadEventData() }
            }
        }
    }

    @ViewBuilder
    private var panelContentView: some View {
        switch panelState.selectedSegment {
        case .liveData:
            ExtendedEventsDataView(
                viewModel: viewModel,
                onPopout: onPopout,
                onDoubleClick: onDoubleClick
            )
        case .messages:
            ExecutionConsoleView(executionMessages: panelState.messages) {
                panelState.clearMessages()
            }
        default:
            EmptyView()
        }
    }

    private var loadingPlaceholder: some View {
        TabInitializingPlaceholder(
            icon: "bolt.horizontal",
            title: "Loading Extended Events",
            subtitle: "Fetching session data..."
        )
    }

    private func errorPlaceholder(_ message: String) -> some View {
        TabContentUnavailableView("Could Not Load Extended Events", systemImage: "exclamationmark.triangle") {
            Text(message)
        } actions: {
            Button("Try Again") { Task { await viewModel.loadSessions() } }
                .buttonStyle(.bordered)
        }
    }
}
