import SwiftUI

struct SidebarMenu: View {
    @Binding var selectedConnectionID: UUID?
    @Binding var selectedIdentityID: UUID?
    
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) var connectionStore
    @Environment(NavigationStore.self) private var navigationStore

    @Environment(EnvironmentState.self) var environmentState
    @Environment(AppState.self) var appState
    let onAddConnection: () -> Void

    @State var selectedNavSection: NavSection = .folder
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
                sessions: environmentState.sessionGroup.sessions,
                pendingConnections: environmentState.pendingConnections,
                selectedConnectionID: selectedConnectionID,
                selectedSection: $selectedNavSection,
                bridge: railBridge,
                onSelectSession: { session in
                    environmentState.sessionGroup.setActiveSession(session.id)
                    navigationStore.revealExplorerConnection(session.connection.id)
                },
                onRetryPending: { pending in
                    environmentState.retryPendingConnection(for: pending.connection.id)
                }
            )

            ZStack {
                // The Explorer stays alive behind the other tools so it keeps its scroll
                // position and expansion, and switching back is instant.
                ObjectBrowserSidebarView(
                    selectedConnectionID: $selectedConnectionID,
                    railBridge: railBridge
                )
                .opacity(selectedNavSection == .folder ? 1 : 0)
                .allowsHitTesting(selectedNavSection == .folder)
                .accessibilityHidden(selectedNavSection != .folder)

                if selectedNavSection != .folder {
                    contentView(for: selectedNavSection)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                selectedNavSection = .folder
            }
        }
        .onChange(of: navigationStore.pendingExplorerRevealRequestID) { _, _ in
            guard navigationStore.pendingExplorerRevealConnectionID != nil else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedNavSection = .folder
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateSidebarSearch)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedNavSection = .search
            }
        }
    }

    func connectAndNavigate(to connection: SavedConnection) {
        selectedConnectionID = connection.id
        selectedNavSection = .folder

        environmentState.connect(to: connection)
    }

    private func duplicateConnection(_ connection: SavedConnection, copyBookmarks: Bool) {
        Task {
            pendingDuplicateConnection = nil
            // await environmentState.duplicateConnection(connection, copyBookmarks: copyBookmarks)
        }
    }
}
