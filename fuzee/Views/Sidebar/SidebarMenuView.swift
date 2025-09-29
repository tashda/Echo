import SwiftUI

struct SidebarMenu: View {
    @Binding var selectedConnectionID: UUID?
    @Binding var selectedIdentityID: UUID?
    @EnvironmentObject var appModel: AppModel
    let onAddConnection: () -> Void

    @State private var selectedNavSection: NavSection = .code

    enum NavSection: String, CaseIterable {
        case folder = "Explorer"
        case bookmark = "Bookmarks"
        case search = "Search"
        case issues = "Issues"
        case code = "Development"
        case history = "History"
        case connections = "Connections"
        case database = "Database Administration"

        var icon: String {
            switch self {
            case .folder: return "folder"
            case .bookmark: return "bookmark"
            case .search: return "magnifyingglass"
            case .issues: return "exclamationmark.triangle"
            case .code: return "curlybraces"
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
            case .issues: return "exclamationmark.triangle.fill"
            case .code: return "curlybraces"
            case .history: return "clock.fill"
            case .connections: return "externaldrive.fill"
            case .database: return "cylinder.split.1x2.fill"
            }
        }

        var displayName: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Window controls spacer
            HStack {
                Spacer().frame(width: 78)
                Spacer()
            }
            .frame(height: 28)

            navigationBar
                .frame(height: 36)
                .padding(.horizontal, 12)

            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(NavSection.allCases, id: \.rawValue) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedNavSection = section
                        }
                    } label: {
                        Image(systemName: selectedNavSection == section ? section.activeIcon : section.icon)
                            .font(.system(size: 15, weight: selectedNavSection == section ? .semibold : .regular))
                            .foregroundStyle(selectedNavSection == section ? .blue : .secondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderless)
                    .help(section.displayName)
                }
            }
            .frame(maxWidth: .infinity)

        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedNavSection {
        case .folder, .code:
            ExplorerSidebarView(selectedConnectionID: $selectedConnectionID)
        case .bookmark:
            BookmarksSidebarView(
                icon: "bookmark.fill",
                title: "Bookmarks",
                description: "Saved database queries and bookmarks will appear here"
            )
        case .search:
            SearchSidebarView(
                icon: "magnifyingglass",
                title: "Search",
                description: "Search across databases and schemas"
            )
        case .issues:
            IssuesSidebarView(
                icon: "exclamationmark.triangle.fill",
                title: "Issues",
                description: "Database connection issues and warnings"
            )
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
                    appModel.selectedFolderID = folder?.id
                    selectedConnectionID = nil
                    onAddConnection()
                },
                onEditConnection: { connection in
                    appModel.selectedFolderID = connection.folderID
                    selectedConnectionID = connection.id
                    onAddConnection()
                },
                onConnect: { connection in
                    connectAndNavigate(to: connection)
                },
                onMoveConnection: { connectionID, folderID in
                    appModel.moveConnection(connectionID, toFolder: folderID)
                },
                onMoveFolder: { folderID, parentID in
                    appModel.moveFolder(folderID, toParent: parentID)
                }
            )
        case .database:
            DatabaseSidebarView(
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
            await appModel.connect(to: connection)
        }
    }
}
