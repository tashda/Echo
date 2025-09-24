import SwiftUI

struct SidebarMenu: View {
    let connections: [SavedConnection]
    @Binding var selectedConnectionID: UUID?
    let databaseStructure: [String: DatabaseStructure]
    @EnvironmentObject var appModel: AppModel
    let onAddConnection: () -> Void
    let onDeleteConnection: (UUID) -> Void
    @State private var selectedNavSection: NavSection = .code
    @State private var expandedItems: Set<String> = ["Databases"]
    
    enum NavSection: String, CaseIterable {
        case folder = "Folder"
        case bookmark = "Bookmarks"
        case search = "Search"
        case issues = "Issues"
        case code = "Development"
        case history = "History"
        case connections = "Connections"
        case database = "Database Administration"
        
        var icon: String {
            switch self {
            case .folder:
                return "folder"
            case .bookmark:
                return "bookmark"
            case .search:
                return "magnifyingglass"
            case .issues:
                return "exclamationmark.triangle"
            case .code:
                return "curlybraces"
            case .history:
                return "clock"
            case .connections:
                return "externaldrive"
            case .database:
                return "cylinder.split.1x2"
            }
        }
        
        var activeIcon: String {
            switch self {
            case .folder:
                return "folder.fill"
            case .bookmark:
                return "bookmark.fill"
            case .search:
                return "magnifyingglass"
            case .issues:
                return "exclamationmark.triangle.fill"
            case .code:
                return "curlybraces"
            case .history:
                return "clock.fill"
            case .connections:
                return "externaldrive.fill"
            case .database:
                return "cylinder.split.1x2.fill"
            }
        }
        
        var displayName: String {
            return rawValue
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Window controls spacer
            HStack {
                Spacer()
                    .frame(width: 78) // Space for traffic light buttons
                Spacer()
            }
            .frame(height: 28)
            
            // Icon navigation bar - perfectly centered
            HStack(spacing: 0) {
                // Center the navigation icons
                HStack(spacing: 2) {
                    ForEach(NavSection.allCases, id: \.rawValue) { section in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedNavSection = section
                            }
                        }) {
                            Image(systemName: selectedNavSection == section ? section.activeIcon : section.icon)
                                .font(.system(size: 15, weight: selectedNavSection == section ? .semibold : .regular))
                                .foregroundStyle(selectedNavSection == section ? .blue : .secondary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.borderless)
                        .help(section.displayName)
                    }
                }
                .frame(maxWidth: .infinity) // This centers the icons
                
                // Add button for connections section - positioned at the right
                if selectedNavSection == .connections {
                    Button(action: onAddConnection) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .help("Add Connection")
                    .padding(.trailing, 12)
                }
            }
            .frame(height: 36)
            .padding(.horizontal, 12)
            
            // Content area with seamless integration
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedNavSection {
        case .folder:
            ExplorerSidebarView(
                connections: connections,
                selectedConnectionID: $selectedConnectionID,
                databaseStructure: databaseStructure,
                expandedItems: $expandedItems
            )
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
        case .code:
            ExplorerSidebarView(
                connections: connections,
                selectedConnectionID: $selectedConnectionID,
                databaseStructure: databaseStructure,
                expandedItems: $expandedItems
            )
        case .history:
            HistorySidebarView(
                icon: "clock.fill",
                title: "History",
                description: "Recent database operations and query history"
            )
        case .connections:
            ConnectionsSidebarView(
                connections: connections,
                selectedConnectionID: $selectedConnectionID,
                onAddConnection: onAddConnection,
                onDeleteConnection: onDeleteConnection
            )
        case .database:
            DatabaseSidebarView(
                icon: "cylinder.split.1x2.fill",
                title: "Database",
                description: "Database administration and management tools"
            )
        }
    }
}
