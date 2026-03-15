import SwiftUI
import AppKit
import EchoSense
import PostgresKit
import SQLServerKit

struct ObjectBrowserSidebarView: View {
    @Binding var selectedConnectionID: UUID?

    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @Environment(NavigationStore.self) internal var navigationStore

    @Environment(EnvironmentState.self) internal var environmentState
    @Environment(AppState.self) private var appState

    @State internal var viewModel = ObjectBrowserSidebarViewModel()

    internal var searchText: String {
        get { viewModel.searchText }
        set { viewModel.searchText = newValue }
    }

    internal var sessions: [ConnectionSession] { environmentState.sessionGroup.sessions }

    internal var selectedSession: ConnectionSession? {
        guard let id = selectedConnectionID else { return nil }
        return environmentState.sessionGroup.sessionForConnection(id)
    }

    var body: some View {
        let mainContent = ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    Color.clear
                        .frame(height: SpacingTokens.xxs2)
                        .id(ExplorerSidebarConstants.objectsTopAnchor)

                    if sessions.isEmpty {
                        emptyStateView
                            .padding(.horizontal, SpacingTokens.md)
                            .padding(.top, SpacingTokens.xl)
                    } else {
                        ForEach(sessions, id: \.connection.id) { session in
                            if sidebarSearchQuery == nil || serverMatchesSearch(session) {
                                serverSection(session: session, proxy: proxy)
                            }
                        }

                        Color.clear
                            .frame(height: ExplorerSidebarConstants.bottomControlHeight + ExplorerSidebarConstants.scrollBottomPadding + SpacingTokens.md2)
                    }
                }
            }
            .buttonStyle(.plain)
            .focusable(false)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .contentMargins(.zero, for: .scrollContent)
            .contentShape(Rectangle())
            .coordinateSpace(name: ExplorerSidebarConstants.scrollCoordinateSpace)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !sessions.isEmpty {
                    globalFooterView
                        .padding(.top, SpacingTokens.xxs2)
                        .padding(.bottom, SpacingTokens.xxs2)
                        .background(ColorTokens.Background.primary)
                }
            }
            .task {
                syncSelectionWithSessions(proxy: proxy)
            }
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.handleSearchTextChanged(proxy: proxy)
            }
            .onChange(of: sessions.map { $0.connection.id }) { _, _ in syncSelectionWithSessions(proxy: proxy) }
            .onChange(of: selectedConnectionID) { _, newValue in
                guard let id = newValue, let session = environmentState.sessionGroup.sessionForConnection(id) else { return }
                environmentState.sessionGroup.setActiveSession(session.id)
            }
            .onAppear {
                viewModel.debouncedSearchText = viewModel.searchText
                if let focus = navigationStore.pendingExplorerFocus { handleExplorerFocus(focus, proxy: proxy) }
            }
            .onChange(of: navigationStore.pendingExplorerFocus) { _, focus in if let focus { handleExplorerFocus(focus, proxy: proxy) } }
            .onDisappear { viewModel.stopSearchDebounce() }
        }
        .environment(viewModel)
        .accessibilityIdentifier("object-browser-sidebar")
        .background(ExplorerSidebarFocusResetter(isSearchFieldFocused: $viewModel.isSearchFieldFocused).allowsHitTesting(false))

        let withSheets = applySheets(to: mainContent)
        let withAlerts = applyAlerts(to: withSheets)

        withAlerts
    }
}
