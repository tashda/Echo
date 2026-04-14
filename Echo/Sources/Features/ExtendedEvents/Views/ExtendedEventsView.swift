import SwiftUI
import SQLServerKit

struct ExtendedEventsView: View {
    var viewModel: ExtendedEventsViewModel
    var panelState: BottomPanelState
    let onPopout: ((String) -> Void)?
    var onDoubleClick: (() -> Void)?
    
    @Environment(TabStore.self) private var tabStore

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

    private var isWatchingLiveData: Bool {
        panelState.isOpen && panelState.selectedSegment == .liveData
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var panelState = panelState
        
        TabContentWithPanel(
            panelState: panelState,
            statusBarConfiguration: statusBarConfig
        ) {
            mainContent
        } panelContent: {
            panelContentView
        }
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
    }

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.loadingState == .loading && viewModel.sessions.isEmpty {
            loadingPlaceholder
        } else if case .error(let message) = viewModel.loadingState,
                  viewModel.sessions.isEmpty {
            errorPlaceholder(message)
        } else {
            VStack(spacing: 0) {
                sectionToolbar
                Divider()
                ExtendedEventsSessionList(viewModel: viewModel) { sessionName in
                    viewModel.selectedSessionName = sessionName
                    panelState.selectedSegment = .liveData
                    panelState.isOpen = true
                    Task { await viewModel.loadEventData() }
                }
            }
        }
    }

    private var sectionToolbar: some View {
        TabSectionToolbar {
            Button {
                viewModel.showCreateSheet = true
            } label: {
                Label("New Session", systemImage: "plus")
                    .font(TypographyTokens.detail)
            }
            .buttonStyle(.borderless)
            .help("New Extended Events Session")
        } controls: {
            watchLiveDataToggle
        }
    }

    @ViewBuilder
    private var watchLiveDataToggle: some View {
        @Bindable var panelState = panelState
        let selectedSession = viewModel.sessions.first(where: { $0.name == viewModel.selectedSessionName })
        let canWatch = selectedSession?.isRunning == true

        Toggle(
            "Watch Live Data",
            systemImage: "waveform.path.ecg",
            isOn: Binding(
                get: { isWatchingLiveData },
                set: { newValue in
                    if newValue {
                        panelState.selectedSegment = .liveData
                        panelState.isOpen = true
                        Task { await viewModel.loadEventData() }
                    } else {
                        panelState.isOpen = false
                    }
                }
            )
        )
        .toggleStyle(.button)
        .controlSize(.small)
        .disabled(!canWatch && !isWatchingLiveData)
        .help(canWatch ? "Toggle live event streaming" : "Select a running session to watch live data")
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

    private var statusBarConfig: BottomPanelStatusBarConfiguration {
        let connText = tabStore.activeTab?.connection.connectionName ?? "Server"

        var config = BottomPanelStatusBarConfiguration(
            serverName: connText,
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

        if !viewModel.eventData.isEmpty {
            config.metrics = .init(
                rowCountText: "\(viewModel.eventData.count)",
                rowCountLabel: viewModel.eventData.count == 1 ? "event" : "events",
                durationText: nil
            )
        }

        if isWatchingLiveData && viewModel.eventDataLoadingState == .loading {
            config.statusBubble = .init(label: "Capturing", tint: .orange, isPulsing: true)
        }

        return config
    }

    private var loadingPlaceholder: some View {
        TabInitializingPlaceholder(
            icon: "bolt.horizontal",
            title: "Loading Extended Events",
            subtitle: "Fetching session data..."
        )
    }

    private func errorPlaceholder(_ message: String) -> some View {
        VStack(spacing: SpacingTokens.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(ColorTokens.Status.warning)
            Text("Could not load Extended Events")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)
            Text(message)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
