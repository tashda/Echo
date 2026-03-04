import SwiftUI

struct DatabaseBreadcrumbMenu: View {
    @Environment(ConnectionStore.self) private var connectionStore
    @EnvironmentObject private var workspaceSessionStore: WorkspaceSessionStore
    
    @State private var searchText = ""
    @State private var availableDatabases: [DatabaseInfo] = []

    private var connectionID: UUID? {
        connectionStore.selectedConnectionID
    }

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
            .padding(.bottom, 8)

            Divider()

            // List
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if availableDatabases.isEmpty {
                        Text("Loading databases...")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    } else if filteredDatabases.isEmpty {
                        Text("No matches found")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(filteredDatabases) { database in
                            databaseRow(database)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 300)

            Divider()

            // Footer actions
            Button(action: {
                Task {
                    if let connectionID {
                        await workspaceSessionStore.refreshDatabaseStructure(for: connectionID, scope: .full)
                        await loadDatabases()
                    }
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh List")
                    Spacer()
                }
                .font(.system(size: 12))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 240)
        .onAppear {
            Task {
                await loadDatabases()
            }
        }
    }

    private func databaseRow(_ database: DatabaseInfo) -> some View {
        Button(action: {
            selectDatabase(database)
        }) {
            HStack {
                Image(systemName: "cylinder")
                    .foregroundStyle(.secondary)
                Text(database.name)
                    .font(.system(size: 13))
                Spacer()
                if isSelected(database) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected(database) ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }

    private func isSelected(_ database: DatabaseInfo) -> Bool {
        guard let connectionID else { return false }
        return workspaceSessionStore.sessionManager.sessionForConnection(connectionID)?.selectedDatabaseName == database.name
    }

    private func selectDatabase(_ database: DatabaseInfo) {
        guard let connectionID,
              let session = workspaceSessionStore.sessionManager.sessionForConnection(connectionID) else { return }
        
        Task {
            await workspaceSessionStore.loadSchemaForDatabase(database.name, connectionSession: session)
        }
    }

    private func loadDatabases() async {
        guard let connectionID,
              let session = workspaceSessionStore.sessionManager.sessionForConnection(connectionID) else { return }

        if let structure = session.databaseStructure {
            self.availableDatabases = structure.databases
        } else {
            // Try to load if not available
            await workspaceSessionStore.refreshDatabaseStructure(for: session.id, scope: .full)
            if let structure = session.databaseStructure {
                self.availableDatabases = structure.databases
            }
        }
    }
}
