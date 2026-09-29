import SwiftUI

struct SidebarMenu: View {
    @Binding var selectedConnectionID: UUID?
    @Binding var selectedIdentityID: UUID?
    
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) var connectionStore
    @Environment(NavigationStore.self) var navigationStore

    @Environment(EnvironmentState.self) var environmentState
    @Environment(AppState.self) var appState
    /// Shared with the rail beside the tree, so the rail follows the tree's scrolling.
    let railBridge: ServerRailBridge
    let onAddConnection: () -> Void

    @State var pendingDuplicateConnection: SavedConnection?

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
                    .id(navigationStore.sidebarSection)
                    .transition(.opacity.combined(with: .offset(y: SpacingTokens.xxs)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            // The tree stays alive while hidden, so focus and search requests still arrive here.
            appState.isWorkspaceTreeVisible = true
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
            appState.isWorkspaceTreeVisible = true
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
