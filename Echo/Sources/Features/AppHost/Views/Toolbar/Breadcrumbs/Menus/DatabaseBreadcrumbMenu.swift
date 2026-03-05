import SwiftUI

struct DatabaseBreadcrumbMenu: View {
    @Environment(ConnectionStore.self) private var connectionStore
    @EnvironmentObject private var environmentState: EnvironmentState
    
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
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(.primary)

                MenuSearchField(text: $searchText, placeholder: "Search databases...")
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.top, SpacingTokens.md)
            .padding(.bottom, SpacingTokens.xs)

            Divider()

            // List
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if availableDatabases.isEmpty {
                        Text("Loading databases...")
                            .font(TypographyTokens.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, SpacingTokens.md)
                            .padding(.vertical, SpacingTokens.xs)
                    } else if filteredDatabases.isEmpty {
                        Text("No matches found")
                            .font(TypographyTokens.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, SpacingTokens.md)
                            .padding(.vertical, SpacingTokens.xs)
                    } else {
                        ForEach(filteredDatabases) { database in
                            databaseRow(database)
                        }
                    }
                }
                .padding(.vertical, SpacingTokens.xs)
            }
            .frame(maxHeight: 300)

            Divider()

            // Footer actions
            Button(action: {
                Task {
                    if let connectionID {
                        await environmentState.refreshDatabaseStructure(for: connectionID, scope: .full)
                        await loadDatabases()
                    }
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh List")
                    Spacer()
                }
                .font(TypographyTokens.caption2)
                .padding(.horizontal, SpacingTokens.md)
                .padding(.vertical, SpacingTokens.xs)
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
                    .font(TypographyTokens.standard)
                Spacer()
                if isSelected(database) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xxs2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected(database) ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, SpacingTokens.xxs)
    }

    private func isSelected(_ database: DatabaseInfo) -> Bool {
        guard let connectionID else { return false }
        return environmentState.sessionCoordinator.sessionForConnection(connectionID)?.selectedDatabaseName == database.name
    }

    private func selectDatabase(_ database: DatabaseInfo) {
        guard let connectionID,
              let session = environmentState.sessionCoordinator.sessionForConnection(connectionID) else { return }
        
        Task {
            await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
        }
    }

    private func loadDatabases() async {
        guard let connectionID,
              let session = environmentState.sessionCoordinator.sessionForConnection(connectionID) else { return }

        if let structure = session.databaseStructure {
            self.availableDatabases = structure.databases
        } else {
            // Try to load if not available
            await environmentState.refreshDatabaseStructure(for: session.id, scope: .full)
            if let structure = session.databaseStructure {
                self.availableDatabases = structure.databases
            }
        }
    }
}
