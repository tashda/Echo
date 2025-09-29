import SwiftUI

struct ExplorerSidebarView: View {
    @Binding var selectedConnectionID: UUID?
    @EnvironmentObject var appModel: AppModel

    @State private var searchText = ""
    @State private var selectedSchemaName: String?
    @State private var expandedObjectGroups: Set<SchemaObjectInfo.ObjectType> = Set(SchemaObjectInfo.ObjectType.allCases)

    private var sessions: [ConnectionSession] {
        appModel.sessionManager.sessions
    }

    private var selectedSession: ConnectionSession? {
        guard let id = selectedConnectionID else { return nil }
        return appModel.sessionManager.sessionForConnection(id)
    }

    private func selectedDatabase(in structure: DatabaseStructure, for session: ConnectionSession) -> Database? {
        guard let selectedName = session.selectedDatabaseName else { return structure.databases.first }
        return structure.databases.first { $0.name == selectedName }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: .sectionHeaders) {
                    if !sessions.isEmpty {
                        connectedServersSection
                        Divider()
                            .padding(.horizontal, 16)
                    }

                    if let session = selectedSession,
                       let structure = session.databaseStructure,
                       let database = selectedDatabase(in: structure, for: session) {

                        Color.clear
                            .frame(height: 0)
                            .id(ExplorerSidebarConstants.objectsTopAnchor)

                        DatabaseObjectBrowserView(
                            database: database,
                            connection: session.connection,
                            searchText: $searchText,
                            selectedSchemaName: $selectedSchemaName,
                            expandedObjectGroups: $expandedObjectGroups,
                            coordinateSpaceName: ExplorerSidebarConstants.scrollCoordinateSpace,
                            scrollTo: { id, anchor in
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    proxy.scrollTo(id, anchor: anchor)
                                }
                            }
                        )
                        .environmentObject(appModel)
                        .padding(.horizontal, 12)

                        if !database.schemas.isEmpty {
                            Divider()
                                .padding(.horizontal, 16)

                            BottomControlsSection(
                                database: database,
                                searchText: $searchText,
                                selectedSchemaName: $selectedSchemaName
                            )
                            .padding(.horizontal, 16)
                        }
                    } else if selectedSession != nil {
                        loadingView("Loading database structure…")
                            .padding(.horizontal, 16)
                    } else {
                        emptyStateView
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
            .coordinateSpace(name: ExplorerSidebarConstants.scrollCoordinateSpace)
            .onAppear {
                syncSelectionWithSessions()
            }
            .onChange(of: sessions.map { $0.connection.id }) { _ in
                syncSelectionWithSessions()
            }
            .onChange(of: selectedConnectionID) { newValue in
                guard let id = newValue,
                      let session = appModel.sessionManager.sessionForConnection(id) else { return }
                appModel.sessionManager.setActiveSession(session.id)
                resetFilters()
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                }
            }
            .onChange(of: selectedSchemaName) { _ in
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                }
            }
            .onChange(of: selectedSession?.selectedDatabaseName ?? "") { _ in
                resetFilters()
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                }
            }
        }
    }

    private var connectedServersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Connected Servers")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()

                if sessions.isEmpty {
                    Text("No connections")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 10) {
                ForEach(sessions, id: \.id) { session in
                    ModernServerCard(
                        session: session,
                        isSelected: session.connection.id == selectedConnectionID,
                        onSelect: {
                            selectedConnectionID = session.connection.id
                        }
                    )
                    .environmentObject(appModel)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Database Connected")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text("Connect to a database to explore its structure")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 40)
    }

    private func loadingView(_ text: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)

            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
    }

    private func syncSelectionWithSessions() {
        if selectedConnectionID == nil || !sessions.contains(where: { $0.connection.id == selectedConnectionID }) {
            selectedConnectionID = sessions.first?.connection.id
        }
    }

    private func resetFilters() {
        searchText = ""
        selectedSchemaName = nil
    }
}

private enum ExplorerSidebarConstants {
    static let scrollCoordinateSpace = "ExplorerSidebarScrollSpace"
    static let objectsTopAnchor = "ExplorerSidebarObjectsTop"
}

// MARK: - Bottom Controls
struct BottomControlsSection: View {
    let database: Database
    @Binding var searchText: String
    @Binding var selectedSchemaName: String?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Search objects...", text: $searchText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }

            if database.schemas.count > 1 {
                HStack {
                    Text("Schema:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Schema", selection: $selectedSchemaName) {
                        Text("All Schemas")
                            .tag(nil as String?)

                        ForEach(database.schemas, id: \.name) { schema in
                            Text("\(schema.name) (\(schema.objects.count))")
                                .tag(schema.name as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Modern Server Card
struct ModernServerCard: View {
    let session: ConnectionSession
    let isSelected: Bool
    let onSelect: () -> Void
    @EnvironmentObject var appModel: AppModel

    @State private var showingDatabasePicker = false

    private var availableDatabases: [Database] {
        session.databaseStructure?.databases ?? []
    }

    private let compactGridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if isSelected {
                    showingDatabasePicker.toggle()
                } else {
                    onSelect()
                }
            } label: {
                HStack(spacing: 12) {
                    // Connection status indicator
                    Circle()
                        .fill(session.isConnected ? .green : .red)
                        .frame(width: 8, height: 8)

                    // Database icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(session.connection.color.opacity(0.15))
                            .frame(width: 28, height: 28)

                        Image(systemName: session.connection.databaseType.iconName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(session.connection.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.connection.connectionName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Text("\(session.connection.host):\(session.connection.port)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isSelected && !availableDatabases.isEmpty {
                        HStack(spacing: 4) {
                            Text("\(availableDatabases.count)")
                                .font(.caption)
                                .fontWeight(.medium)

                            Image(systemName: showingDatabasePicker ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                    }

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? .selection : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(.separator, lineWidth: 0.5)
                    )
            )

            if isSelected && showingDatabasePicker && !availableDatabases.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.horizontal, 12)

                    ScrollView {
                        LazyVGrid(columns: compactGridColumns, spacing: 8) {
                            ForEach(availableDatabases) { database in
                                CompactDatabaseCard(
                                    database: database,
                                    isSelected: database.name == session.selectedDatabaseName,
                                    serverColor: session.connection.color
                                ) {
                                    showingDatabasePicker = false
                                    Task { @MainActor in
                                        await switchToDatabase(database.name, in: session)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(maxHeight: 200)
                }
                .padding(.top, 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showingDatabasePicker)
    }

    private func switchToDatabase(_ databaseName: String, in session: ConnectionSession) async {
        session.selectedDatabaseName = databaseName
        // Trigger any necessary reload logic here
        await appModel.sessionManager.refreshDatabaseStructure(for: session.id)
    }
}

// MARK: - Compact Database Card
struct CompactDatabaseCard: View {
    let database: Database
    let isSelected: Bool
    let serverColor: Color
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(serverColor.opacity(0.3))
                        .frame(width: 6, height: 6)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.blue)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(database.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("\(database.schemas.count) schemas")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? serverColor.opacity(0.1) : .regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? serverColor.opacity(0.3) : .separator, lineWidth: 0.5)
                )
        )
    }
}