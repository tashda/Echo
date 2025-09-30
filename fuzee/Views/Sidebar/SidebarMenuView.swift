import SwiftUI

struct SidebarMenu: View {
    @Binding var selectedConnectionID: UUID?
    @Binding var selectedIdentityID: UUID?
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var appState: AppState
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
            navigationBar
                .frame(height: 28)
                .padding(.top, 8)

            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 0) {
            xcodeStyleSegmentedControl
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var xcodeStyleSegmentedControl: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.primary.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 0.5)
            )
            .overlay(
                HStack(spacing: 0) {
                    ForEach(Array(NavSection.allCases.enumerated()), id: \.element.rawValue) { index, section in
                        // Full-height button that fills the space
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedNavSection = section
                            }
                        } label: {
                            ZStack {
                                // Invisible background for full click area
                                Rectangle()
                                    .fill(.clear)
                                    .contentShape(Rectangle())

                                // Icon centered in the area
                                Image(systemName: selectedNavSection == section ? section.activeIcon : section.icon)
                                    .font(.system(size: 14, weight: selectedNavSection == section ? .medium : .regular))
                                    .foregroundStyle(selectedNavSection == section ? .white : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.tint)
                                .opacity(selectedNavSection == section ? 1 : 0)
                                .animation(.easeInOut(duration: 0.15), value: selectedNavSection == section)
                        )
                        .help(section.displayName)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Divider after each item (except the last)
                        if index < NavSection.allCases.count - 1 {
                            let shouldShowDivider = selectedNavSection != section &&
                                                   selectedNavSection != NavSection.allCases[index + 1]
                            Rectangle()
                                .fill(.primary.opacity(0.15))
                                .frame(width: 0.5)
                                .padding(.vertical, 6)
                                .opacity(shouldShowDivider ? 1 : 0)
                                .animation(.easeInOut(duration: 0.15), value: shouldShowDivider)
                        }
                    }
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 3)
            )
            .padding(.horizontal, 6)
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
                },
                onDuplicateConnection: { connection in
                    Task { await appModel.duplicateConnection(connection) }
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
