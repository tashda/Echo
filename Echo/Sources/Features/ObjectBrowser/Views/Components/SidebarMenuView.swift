import SwiftUI

struct SidebarMenu: View {
    @Binding var selectedConnectionID: UUID?
    @Binding var selectedIdentityID: UUID?
    
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) var connectionStore
    @Environment(NavigationStore.self) var navigationStore
    @Environment(TabStore.self) private var tabStore

    @Environment(EnvironmentState.self) var environmentState
    @Environment(AppState.self) var appState
    let onAddConnection: () -> Void

    @State var pendingDuplicateConnection: SavedConnection?
    @State private var railBridge = ServerRailBridge()

    enum NavSection: String, CaseIterable {
        case folder = "Explorer"
        case bookmark = "Bookmarks"
        case search = "Search"
        case clipboard = "Clipboard"
        case snippets = "Snippets"
        case history = "History"
        case connections = "Connections"

        var icon: String {
            switch self {
            case .folder: return "folder"
            case .bookmark: return "bookmark"
            case .search: return "magnifyingglass"
            case .clipboard: return "clipboard"
            case .snippets: return "curlybraces"
            case .history: return "clock"
            case .connections: return "externaldrive"
            }
        }

        var displayName: String { rawValue }
    }

    var body: some View {
        HStack(spacing: 0) {
            ServerRail(
                style: .embedded,
                sessions: environmentState.sessionGroup.sessions,
                pendingConnections: environmentState.pendingConnections,
                savedConnections: connectionStore.connections,
                selectedConnectionID: selectedConnectionID,
                runningQueryCounts: tabStore.runningQueryCountsByConnection,
                selectedSection: Bindable(navigationStore).sidebarSection,
                isGlanceOpen: Bindable(navigationStore).isQueryGlanceOpen,
                bridge: railBridge,
                onSelectSession: { session in
                    environmentState.sessionGroup.setActiveSession(session.id)
                    navigationStore.revealExplorerConnection(session.connection.id)
                },
                onRetryPending: { pending in
                    environmentState.retryPendingConnection(for: pending.connection.id)
                },
                onConnect: { connection in
                    connectAndNavigate(to: connection)
                }
            )

            ZStack {
                // The Explorer stays alive behind the other tools so it keeps its scroll
                // position and expansion, and switching back is instant.
                ObjectBrowserSidebarView(
                    selectedConnectionID: $selectedConnectionID,
                    railBridge: railBridge
                )
                .opacity(navigationStore.sidebarSection == .folder ? 1 : 0)
                .allowsHitTesting(navigationStore.sidebarSection == .folder)
                .accessibilityHidden(navigationStore.sidebarSection != .folder)

                if navigationStore.sidebarSection != .folder {
                    contentView(for: navigationStore.sidebarSection)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.leading, -LayoutTokens.ServerRail.contentLeadingOverlap)
            .overlay(alignment: .topLeading) {
                QueryGlancePanel(
                    sessions: environmentState.sessionGroup.sessions,
                    isOpen: navigationStore.isQueryGlanceOpen,
                    onClose: { navigationStore.isQueryGlanceOpen = false }
                )
                .padding(.leading, LayoutTokens.QueryGlance.railGap)
                .padding(.trailing, SpacingTokens.xs)
                .padding(.top, SpacingTokens.xxs)
            }
        }
        .padding(.top, appState.workspaceTabBarStyle.chromeTopPadding)
        .confirmationDialog(
            "Duplicate Connection",
            isPresented: Binding(
                get: { pendingDuplicateConnection != nil },
                set: { isPresented in if !isPresented { pendingDuplicateConnection = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDuplicateConnection
        ) { connection in
            Button("Duplicate with Bookmark History") {
                duplicateConnection(connection, copyBookmarks: true)
            }

            Button("Duplicate Only Connection") {
                duplicateConnection(connection, copyBookmarks: false)
            }

            Button("Cancel", role: .cancel) {
                pendingDuplicateConnection = nil
            }
        } message: { _ in
            Text("Do you want to copy the bookmark history into the duplicated connection?")
        }
        .onChange(of: navigationStore.pendingExplorerFocus) { _, focus in
            guard focus != nil else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                navigationStore.sidebarSection = .folder
            }
        }
        .onChange(of: navigationStore.pendingExplorerRevealRequestID) { _, _ in
            guard navigationStore.pendingExplorerRevealConnectionID != nil else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                navigationStore.sidebarSection = .folder
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateSidebarSearch)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                navigationStore.sidebarSection = .search
            }
        }
    }

    func connectAndNavigate(to connection: SavedConnection) {
        selectedConnectionID = connection.id
        navigationStore.sidebarSection = .folder

        environmentState.connect(to: connection)
    }

    private func duplicateConnection(_ connection: SavedConnection, copyBookmarks: Bool) {
        Task {
            pendingDuplicateConnection = nil
            // await environmentState.duplicateConnection(connection, copyBookmarks: copyBookmarks)
        }
    }
}
