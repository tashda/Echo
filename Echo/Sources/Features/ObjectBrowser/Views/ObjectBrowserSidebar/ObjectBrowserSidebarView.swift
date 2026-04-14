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
    @Environment(\.openWindow) internal var openWindow

    @State internal var viewModel = ObjectBrowserSidebarViewModel()
    @State internal var sheetState = SidebarSheetState()

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
                        .frame(height: 0)
                        .id(ExplorerSidebarConstants.objectsTopAnchor)

                    let pending = environmentState.pendingConnections

                    if sessions.isEmpty && pending.isEmpty {
                        emptyStateView
                            .padding(.horizontal, SpacingTokens.md)
                            .padding(.top, SpacingTokens.xl)
                    } else {
                        Color.clear
                            .frame(height: SpacingTokens.xs)

                        ForEach(pending) { item in
                            pendingConnectionSection(pending: item)
                                .padding(.bottom, SpacingTokens.xxs)
                        }

                        ForEach(Array(sessions.enumerated()), id: \.element.connection.id) { index, session in
                            if index > 0 || !pending.isEmpty {
                                Spacer()
                                    .frame(height: SpacingTokens.xs)
                            }
                            serverSection(session: session, proxy: proxy)
                        }

                        Color.clear
                            .frame(height: ExplorerSidebarConstants.scrollBottomPadding + SpacingTokens.md2)
                    }
                }
            }
            .contentMargins(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding, for: .scrollContent)
            .scrollIndicators(.automatic)
            .buttonStyle(.plain)
            .focusable(false)
            .scrollContentBackground(.hidden)
            .coordinateSpace(name: ExplorerSidebarConstants.scrollCoordinateSpace)
            .clipped()
            .task {
                syncSelectionWithSessions(proxy: proxy)
            }
            .onChange(of: sessions.map(\.connection.id)) { oldIDs, newIDs in
                syncSelectionWithSessions(proxy: proxy)
                let added = Set(newIDs).subtracting(oldIDs)
                if !added.isEmpty {
                    viewModel.recentlyConnectedIDs.formUnion(added)
                }
            }
            .onChange(of: selectedConnectionID) { _, newValue in
                guard let id = newValue, let session = environmentState.sessionGroup.sessionForConnection(id) else { return }
                environmentState.sessionGroup.setActiveSession(session.id)
            }
            .onAppear {
                if let focus = navigationStore.pendingExplorerFocus { handleExplorerFocus(focus, proxy: proxy) }
            }
            .onChange(of: navigationStore.pendingExplorerFocus) { _, focus in if let focus { handleExplorerFocus(focus, proxy: proxy) } }
        }
        .environment(viewModel)
        .environment(sheetState)
        .environment(\.sidebarDensity, projectStore.globalSettings.sidebarDensity)
        .accessibilityIdentifier("object-browser-sidebar")

        let withSheets = applySheets(to: mainContent)
        let withAlerts = applyAlerts(to: withSheets)

        withAlerts
    }
}
