import SwiftUI

struct DatabaseBreadcrumbMenu: View {
    @EnvironmentObject private var appModel: AppModel
    let connectionID: UUID

    @State private var searchText = ""
    @State private var availableDatabases: [DatabaseInfo] = []

    private var filteredDatabases: [DatabaseInfo] {
        if searchText.isEmpty {
            return availableDatabases
        }
        return availableDatabases.filter { database in
            database.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with search
            VStack(alignment: .leading, spacing: 8) {
                Text("Databases")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                MenuSearchField(text: $searchText, placeholder: "Search databases...")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Database list
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if !filteredDatabases.isEmpty {
                        ForEach(filteredDatabases, id: \.name) { database in
                            DatabaseMenuItem(
                                database: database,
                                connectionID: connectionID
                            )
                        }
                    } else if !searchText.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                            Text("No databases found")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading databases...")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(maxHeight: 200)
        }
        .frame(width: 260)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            loadDatabases()
        }
    }

    private func loadDatabases() {
        Task { @MainActor in
            guard let session = appModel.sessionManager.sessionForConnection(connectionID) else {
                return
            }

            // Get databases from session
            if let structure = session.databaseStructure {
                availableDatabases = structure.databases.sorted { $0.name < $1.name }
            } else {
                // Request structure refresh if not available
                await appModel.refreshDatabaseStructure(for: session.id, scope: .full)

                // Try again after refresh
                if let structure = session.databaseStructure {
                    availableDatabases = structure.databases.sorted { $0.name < $1.name }
                }
            }
        }
    }
}

// MARK: - Database Menu Item

struct DatabaseMenuItem: View {
    let database: DatabaseInfo
    let connectionID: UUID

    @EnvironmentObject private var appModel: AppModel
    @State private var isHovered = false

    private var isSelected: Bool {
        guard let session = appModel.sessionManager.sessionForConnection(connectionID) else {
            return false
        }
        return session.selectedDatabaseName == database.name
    }

    private var databaseStats: (schemas: Int, tables: Int, views: Int) {
        let schemas = database.schemas.count
        let tables = database.schemas.flatMap { $0.objects }.filter { $0.type == .table }.count
        let views = database.schemas.flatMap { $0.objects }.filter { $0.type == .view || $0.type == .materializedView }.count
        return (schemas, tables, views)
    }

    var body: some View {
        Button(action: {
            // Handle database selection
            Task { @MainActor in
                guard let session = appModel.sessionManager.sessionForConnection(connectionID) else {
                    return
                }

                await appModel.loadSchemaForDatabase(database.name, connectionSession: session)
                appModel.selectedConnectionID = connectionID
            }
        }) {
            HStack(spacing: 12) {
                // Database icon
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.blue.opacity(0.15))
                        .frame(width: 24, height: 24)
                    Image(systemName: "cylinder.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.blue)
                }

                // Database info
                VStack(alignment: .leading, spacing: 2) {
                    Text(database.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Stats
                    HStack(spacing: 8) {
                        if databaseStats.schemas > 0 {
                            DatabaseStatBadge(icon: "list.bullet", count: databaseStats.schemas, label: "schema")
                        }
                        if databaseStats.tables > 0 {
                            DatabaseStatBadge(icon: "tablecells", count: databaseStats.tables, label: "table")
                        }
                        if databaseStats.views > 0 {
                            DatabaseStatBadge(icon: "eye", count: databaseStats.views, label: "view")
                        }
                    }
                }

                Spacer(minLength: 8)

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : (isHovered ? Color.accentColor.opacity(0.06) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Database Stat Badge

struct DatabaseStatBadge: View {
    let icon: String
    let count: Int
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)

            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .help("\(count) \(label)\(count != 1 ? "s" : "")")
    }
}