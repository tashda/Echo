import SwiftUI

struct SidebarMenu: View {
    @Binding var selectedConnectionID: UUID?
    @Binding var selectedIdentityID: UUID?
    
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    
    @EnvironmentObject var environmentState: EnvironmentState
    @EnvironmentObject var appState: AppState
    let onAddConnection: () -> Void

    @State private var selectedNavSection: NavSection = .folder
    @State private var pendingDuplicateConnection: SavedConnection?

    enum NavSection: String, CaseIterable {
        case folder = "Explorer"
        case bookmark = "Bookmarks"
        case search = "Search"
        case clipboard = "Clipboard"
        case history = "History"
        case connections = "Connections"
        case database = "Database Administration"

        var icon: String {
            switch self {
            case .folder: return "folder"
            case .bookmark: return "bookmark"
            case .search: return "magnifyingglass"
            case .clipboard: return "clipboard"
            case .history: return "clock"
            case .connections: return "externaldrive"
            case .database: return "cylinder.split.1x2"
            }
        }

        var activeIcon: String {
            switch self {
            case .folder: return "folder.fill"
            case .bookmark: return "bookmark.fill"
            case .search: return "magnifyingglass"
            case .clipboard: return "clipboard.fill"
            case .history: return "clock.fill"
            case .connections: return "externaldrive.fill"
            case .database: return "cylinder.split.1x2.fill"
            }
        }

        var displayName: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
                .padding(.horizontal, 6)
                .padding(.bottom, 8)

            contentView
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
    }

    private var navigationBar: some View {
        xcodeStyleSegmentedControl
    }

    @ViewBuilder
    private var xcodeStyleSegmentedControl: some View {
        let controlHeight: CGFloat = WorkspaceChromeMetrics.chromeBackgroundHeight
        let controlCornerRadius: CGFloat = controlHeight / 2
        let segmentCornerRadius: CGFloat = controlCornerRadius - 4

        RoundedRectangle(cornerRadius: controlCornerRadius, style: .continuous)
            .fill(.primary.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: controlCornerRadius, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 0.5)
            )
            .overlay(
                HStack(spacing: 0) {
                    ForEach(Array(NavSection.allCases.enumerated()), id: \.element.rawValue) { index, section in
                        let isEdgeSegment = index == 0 || index == NavSection.allCases.count - 1
                        let highlightCornerRadius = isEdgeSegment ? controlCornerRadius : segmentCornerRadius

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedNavSection = section
                            }
                        } label: {
                            ZStack {
                                Rectangle()
                                    .fill(.clear)
                                    .contentShape(Rectangle())

                                Image(systemName: selectedNavSection == section ? section.activeIcon : section.icon)
                                    .font(.system(size: 14, weight: .medium, design: .default))
                                    .foregroundStyle(selectedNavSection == section ? .white : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: highlightCornerRadius, style: .continuous)
                                .fill(.tint)
                                .opacity(selectedNavSection == section ? 1 : 0)
                                .animation(.easeInOut(duration: 0.15), value: selectedNavSection)
                        )
                        .help(section.displayName)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if index < NavSection.allCases.count - 1 {
                            let shouldShowDivider = selectedNavSection != section &&
                                selectedNavSection != NavSection.allCases[index + 1]
                            Rectangle()
                                .fill(.primary.opacity(0.15))
                                .frame(width: 0.5)
                                .opacity(shouldShowDivider ? 1 : 0)
                                .animation(.easeInOut(duration: 0.15), value: shouldShowDivider)
                        }
                    }
                }
                .padding(.horizontal, 0)
                .padding(.vertical, 0)
            )
            .frame(height: controlHeight)
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedNavSection {
        case .folder:
            ObjectBrowserSidebarView(selectedConnectionID: $selectedConnectionID)
        case .bookmark:
            BookmarksSidebarView()
        case .search:
            SearchSidebarView()
        case .clipboard:
            ClipboardHistoryView()
        case .history:
            HistorySidebarView(
                icon: "clock.fill",
                title: "History",
                description: "Recent database operations and query history"
            )
        case .connections:
            ConnectionsSidebarView(
                selectedConnectionID: $selectedConnectionID,
                selectedIdentityID: $selectedIdentityID,
                onCreateConnection: { folder in
                    connectionStore.selectedFolderID = folder?.id
                    selectedConnectionID = nil
                    onAddConnection()
                },
                onEditConnection: { connection in
                    connectionStore.selectedFolderID = connection.folderID
                    selectedConnectionID = connection.id
                    onAddConnection()
                },
                onConnect: { connection in
                    connectAndNavigate(to: connection)
                },
                onMoveConnection: { connectionID, folderID in
                    Task { @MainActor in
                        if var connection = connectionStore.connections.first(where: { $0.id == connectionID }) {
                            connection.folderID = folderID
                            try? await connectionStore.updateConnection(connection)
                        }
                    }
                },
                onMoveFolder: { folderID, parentID in
                    Task { @MainActor in
                        if var folder = connectionStore.folders.first(where: { $0.id == folderID }) {
                            folder.parentFolderID = parentID
                            try? await connectionStore.saveFolders()
                        }
                    }
                },
                onDuplicateConnection: { connection in
                    pendingDuplicateConnection = connection
                }
            )
        case .database:
            DatabaseSidebarView(
                selectedConnectionID: $selectedConnectionID,
                icon: "cylinder.split.1x2.fill",
                title: "Database",
                description: "Database administration and management tools"
            )
        }
    }

    private func connectAndNavigate(to connection: SavedConnection) {
        selectedConnectionID = connection.id
        selectedNavSection = .folder

        Task {
            await environmentState.connect(to: connection)
        }
    }

    private func duplicateConnection(_ connection: SavedConnection, copyBookmarks: Bool) {
        Task {
            pendingDuplicateConnection = nil
            // await environmentState.duplicateConnection(connection, copyBookmarks: copyBookmarks)
        }
    }
}
