import SwiftUI

struct ExplorerSidebarView: View {
    let connections: [SavedConnection]
    @Binding var selectedConnectionID: UUID?
    let databaseStructure: [String: DatabaseStructure]
    @Binding var expandedItems: Set<String>
    @EnvironmentObject var appModel: AppModel

    @State private var selectedItemID: String? // New state for selection

    private let baseIndent: CGFloat = 16 // Consistent indentation unit

    private var selectedConnection: SavedConnection? {
        guard let id = selectedConnectionID else { return nil }
        return connections.first { $0.id == id }
    }

    private var currentDatabaseStructure: DatabaseStructure? {
        guard let selectedConnectionID = selectedConnectionID else { return nil }
        return databaseStructure[selectedConnectionID.uuidString]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let connection = selectedConnection {
                    // Connection Status Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            // Database Type Icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.blue.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: connection.databaseType.iconName)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(.blue)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(connection.connectionName)
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Text("\(connection.host):\(connection.port)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                if let version = connection.serverVersion {
                                    HStack(spacing: 4) {
                                        Text(connection.databaseType.displayName)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                        Text(version)
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            // Connection Status Indicator
                            VStack(spacing: 6) {
                                Circle()
                                    .fill((appModel.connectionStates[connection.id]?.isConnected ?? false) ? .green : .red)
                                    .frame(width: 8, height: 8)

                                if appModel.connectionStates[connection.id]?.isLoading == true {
                                    ProgressView()
                                        .controlSize(.mini)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }

                    // Database Structure Section
                    if let state = appModel.connectionStates[connection.id], state.isConnected {
                        if let structure = currentDatabaseStructure {
                            VStack(alignment: .leading, spacing: 0) { // Changed spacing to 0
                                ForEach(structure.databases, id: \.name) { db in
                                    SelectableRowContainer(
                                        id: "db:\(db.name)",
                                        selectedItemID: $selectedItemID,
                                        leadingPadding: baseIndent // Level 1 indentation
                                    ) {
                                        DisclosureGroup(
                                            isExpanded: expansionBinding(for: "db:\(db.name)")
                                        ) {
                                            let objectsBySchema = Dictionary(grouping: db.objects, by: { $0.schema })

                                            if objectsBySchema.keys.count == 1 {
                                                let tables = db.tables
                                                if !tables.isEmpty {
                                                    SelectableRowContainer(
                                                        id: "tables_group:\(db.name)",
                                                        selectedItemID: $selectedItemID,
                                                        leadingPadding: baseIndent * 1.5 // Level 2 indentation
                                                    ) {
                                                        DisclosureGroup(
                                                            isExpanded: expansionBinding(for: "tables:\(db.name)")
                                                        ) {
                                                            ForEach(tables) { table in
                                                                SchemaObjectRow(object: table, expandedItems: $expandedItems, selectedItemID: $selectedItemID, leadingPaddingAmount: baseIndent * 3) // Level 3 for object
                                                            }
                                                        } label: {
                                                            Label("Tables", systemImage: "tablecells")
                                                        }
                                                    }
                                                }

                                                let views = db.views
                                                if !views.isEmpty {
                                                    SelectableRowContainer(
                                                        id: "views_group:\(db.name)",
                                                        selectedItemID: $selectedItemID,
                                                        leadingPadding: baseIndent * 1.2 // Level 2 indentation
                                                    ) {
                                                        DisclosureGroup(
                                                            isExpanded: expansionBinding(for: "views:\(db.name)")
                                                        ) {
                                                            ForEach(views) { view in
                                                                SchemaObjectRow(object: view, expandedItems: $expandedItems, selectedItemID: $selectedItemID, leadingPaddingAmount: baseIndent * 3) // Level 3 for object
                                                            }
                                                        } label: {
                                                            Label("Views", systemImage: "eye")
                                                        }
                                                    }
                                                }
                                            } else {
                                                let sortedSchemas = objectsBySchema.keys.sorted()
                                                ForEach(sortedSchemas, id: \.self) { schemaName in
                                                    SelectableRowContainer(
                                                        id: "schema:\(db.name).\(schemaName)",
                                                        selectedItemID: $selectedItemID,
                                                        leadingPadding: baseIndent * 1.2 // Level 2 indentation
                                                    ) {
                                                        DisclosureGroup(
                                                            schemaName,
                                                            isExpanded: expansionBinding(for: "schema:\(db.name).\(schemaName)")
                                                        ) {
                                                            let schemaObjects = objectsBySchema[schemaName] ?? []
                                                            let tables = schemaObjects.filter { $0.type == .table }
                                                            let views = schemaObjects.filter { $0.type == .view }

                                                            if !tables.isEmpty {
                                                                SelectableRowContainer(
                                                                    id: "tables_group:\(db.name).\(schemaName)",
                                                                    selectedItemID: $selectedItemID,
                                                                    leadingPadding: baseIndent * 1.2 // Level 3 indentation
                                                                ) {
                                                                    DisclosureGroup(
                                                                        isExpanded: expansionBinding(for: "tables:\(db.name).\(schemaName)")
                                                                    ) {
                                                                        ForEach(tables) { table in
                                                                            SchemaObjectRow(object: table, expandedItems: $expandedItems, selectedItemID: $selectedItemID, leadingPaddingAmount: baseIndent * 1.2) // Level 4 for object
                                                                        }
                                                                    } label: {
                                                                        Label("Tables", systemImage: "tablecells")
                                                                    }
                                                                }
                                                            }
                                                            if !views.isEmpty {
                                                                SelectableRowContainer(
                                                                    id: "views_group:\(db.name).\(schemaName)",
                                                                    selectedItemID: $selectedItemID,
                                                                    leadingPadding: baseIndent * 3 // Level 3 indentation
                                                                ) {
                                                                    DisclosureGroup(
                                                                        isExpanded: expansionBinding(for: "views:\(db.name).\(schemaName)")
                                                                    ) {
                                                                        ForEach(views) { view in
                                                                            SchemaObjectRow(object: view, expandedItems: $expandedItems, selectedItemID: $selectedItemID, leadingPaddingAmount: baseIndent * 4) // Level 4 for object
                                                                        }
                                                                    } label: {
                                                                        Label("Views", systemImage: "eye")
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        } label: {
                                            Label(db.name, systemImage: "cylinder.split.1x2")
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 12)
                        } else {
                            // Loading database structure
                            VStack(spacing: 12) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading database structure...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        }
                    } else {
                        // Not connected state
                        VStack(spacing: 20) {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 32))
                                .foregroundStyle(.tertiary)

                            VStack(spacing: 8) {
                                Text("Not Connected")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)

                                Text("Connect to browse the database structure")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }

                            Button("Connect") {
                                Task {
                                    await appModel.connect(to: connection)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    // No connection selected
                    VStack(spacing: 24) {
                        Image(systemName: "externaldrive")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)

                        VStack(spacing: 12) {
                            Text("No Database Selected")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)

                            Text("Select a connection from the Connections tab to explore the database schema")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 40)
                }
            }
        }
    }

    private func expansionBinding(for key: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { expandedItems.contains(key) },
            set: { isExpanded in
                if isExpanded {
                    expandedItems.insert(key)
                } else {
                    expandedItems.remove(key)
                }
            }
        )
    }
}



