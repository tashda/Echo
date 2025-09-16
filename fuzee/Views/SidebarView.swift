import SwiftUI

struct SidebarView: View {
    @Binding var connections: [SavedConnection]
    @Binding var selectedConnectionID: UUID?
    @Binding var databaseStructure: [String: DatabaseStructure]
    @EnvironmentObject var appModel: AppModel

    var onAddConnection: () -> Void
    var onDeleteConnection: (UUID) -> Void

    @State private var selectedNavSection: NavSection = .explorer
    @State private var expandedItems: Set<String> = ["Databases"]

    enum NavSection: String, CaseIterable {
        case explorer = "Explorer"
        case connections = "Connections"

        var icon: String {
            switch self {
            case .explorer:
                return "folder"
            case .connections:
                return "externaldrive.connected"
            }
        }

        var activeIcon: String {
            switch self {
            case .explorer:
                return "folder.fill"
            case .connections:
                return "externaldrive.connected.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Section 1: Window Controls Area (Traffic Lights)
            HStack {
                Spacer().frame(width: 78) // Space for traffic lights
                Spacer()
            }.frame(height: 28).background(.regularMaterial)

            // Section 2: Horizontal Navigation Bar (like Xcode)
            HStack(spacing: 0) {
                ForEach(NavSection.allCases, id: \.rawValue) {
                    section in
                    Button(action: {
                        selectedNavSection = section
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: selectedNavSection == section ? section.activeIcon: section.icon).font(.system(size: 14))
                            Text(section.rawValue).font(.system(.subheadline, weight: .medium))
                        }.foregroundStyle(selectedNavSection == section ? .primary: .secondary).padding(.horizontal, 12).padding(.vertical, 8).background(
                            selectedNavSection == section ? Color.accentColor.opacity(0.2): Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                    }.buttonStyle(.borderless).help(section.rawValue)
                }

                Spacer()

                // Add button for connections section
                if selectedNavSection == .connections {
                    Button(action: onAddConnection) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    }.buttonStyle(.borderless).help("Add Connection").padding(.trailing, 12)
                }
            }.padding(.horizontal, 12).padding(.vertical, 8).background(.thickMaterial)

            Divider()

            // Section 3: Content Area
            contentView.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.background(.regularMaterial)
    }

    @ViewBuilder private var contentView: some View {
        switch selectedNavSection {
        case .explorer:
            ExplorerView(
                connections: connections,
                selectedConnectionID: $selectedConnectionID,
                databaseStructure: databaseStructure,
                expandedItems: $expandedItems
            )
        case .connections:
            ConnectionsView(
                connections: connections,
                selectedConnectionID: $selectedConnectionID,
                onAddConnection: onAddConnection,
                onDeleteConnection: onDeleteConnection
            )
        }
    }
}

struct ExplorerView: View {
    let connections: [SavedConnection]
    @Binding var selectedConnectionID: UUID?
    let databaseStructure: [String: DatabaseStructure]
    @Binding var expandedItems: Set<String>
    @EnvironmentObject var appModel: AppModel

    private var selectedConnection: SavedConnection? {
        connections.first {
            $0.id == selectedConnectionID
        }
    }

    private var currentDatabaseStructure: DatabaseStructure? {
        guard let selectedConnectionID = selectedConnectionID else {
            return nil
        }
        return databaseStructure[selectedConnectionID.uuidString]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let connection = selectedConnection {
                    // Connection Status Header with Database Icon and Version
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            // Database Type Icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.blue.opacity(0.15)).frame(width: 36, height: 36)
                                Image(systemName: connection.databaseType.iconName).font(.system(size: 18, weight: .medium)).foregroundStyle(.blue)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(connection.connectionName).font(.callout).fontWeight(.semibold).foregroundStyle(.primary)

                                Text("\(connection.host):\(connection.port)").font(.caption2).foregroundStyle(.secondary)

                                // Database Version
                                if let version = connection.serverVersion {
                                    HStack(spacing: 4) {
                                        Text(connection.databaseType.displayName).font(.caption2).foregroundStyle(.tertiary)
                                        Text(version).font(.caption2).fontWeight(.medium).foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            // Connection Status Indicator
                            let state = appModel.connectionStates[connection.id] ?? .disconnected
                            VStack(spacing: 4) {
                                Circle().fill(state.isConnected ? .green: .red).frame(width: 8, height: 8)

                                if state.isLoading {
                                    ProgressView().controlSize(.mini)
                                }
                            }
                        }.padding(.horizontal, 16).padding(.vertical, 12)

                        Divider().padding(.horizontal, 16)
                    }

                    // Database Structure Section
                    if let state = appModel.connectionStates[connection.id], state.isConnected {
                        if let dbStructure = currentDatabaseStructure {
                            DatabaseStructureView(
                                structure: dbStructure,
                                selectedDatabase: connection.database,
                                expandedItems: $expandedItems
                            )
                        } else {
                            // Loading database structure
                            VStack(spacing: 12) {
                                ProgressView().controlSize(.small)
                                Text("Loading database structure...").font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity).padding(.vertical, 32)
                        }
                    } else {
                        // Not connected state
                        VStack(spacing: 12) {
                            Image(systemName: "link.badge.plus").font(.system(size: 24)).foregroundStyle(.tertiary)

                            Text("Not Connected").font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)

                            Button("Connect") {
                                Task {
                                    await appModel.connect(to: connection)
                                }
                            }.buttonStyle(.bordered).controlSize(.small)
                        }.frame(maxWidth: .infinity).padding(.vertical, 32)
                    }

                } else {
                    // No connection selected
                    VStack(spacing: 16) {
                        Image(systemName: "externaldrive").font(.system(size: 32)).foregroundStyle(.tertiary)

                        Text("No Database Selected").font(.headline).foregroundStyle(.secondary)

                        Text("Select a connection from the Connections tab to explore the database schema").font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(24)
                }
            }
        }
    }
}

struct DatabaseStructureView: View {
    let structure: DatabaseStructure
    let selectedDatabase: String
    @Binding var expandedItems: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Databases Header
            DisclosureGroup(
                isExpanded: Binding(
                    get: {
                        expandedItems.contains("Databases")
                    },
                    set: {
                        isExpanded in
                        if isExpanded {
                            expandedItems.insert("Databases")
                        } else {
                            expandedItems.remove("Databases")
                        }
                    }
                )
            ) {
                ForEach(structure.databases, id: \.name) {
                    database in
                    DatabaseRowView(
                        database: database,
                        isSelected: database.name == selectedDatabase,
                        expandedItems: $expandedItems
                    )
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cylinder.split.1x2.fill").foregroundStyle(.blue).font(.system(size: 12)).frame(width: 16)

                    Text("Databases").font(.callout).fontWeight(.medium)

                    Spacer()

                    Text("\(structure.databases.count)").font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 6).padding(.vertical, 2).background(.quaternary, in: Capsule())
                }.padding(.horizontal, 16).padding(.vertical, 8)
            }
        }
    }
}

struct DatabaseRowView: View {
    let database: DatabaseInfo
    let isSelected: Bool
    @Binding var expandedItems: Set<String>

    private var databaseKey: String {
        "Database_\(database.name)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Database name with selection indicator
            HStack(spacing: 8) {
                Circle().fill(isSelected ? .blue: .clear).stroke(isSelected ? .blue: .secondary, lineWidth: 1).frame(width: 8, height: 8)

                Text(database.name).font(.callout).fontWeight(isSelected ? .semibold: .regular).foregroundStyle(isSelected ? .primary: .secondary)

                Spacer()
            }.padding(.horizontal, 32).padding(.vertical, 4)

            // Schemas for the current database
            if isSelected && !database.schemas.isEmpty {
                ForEach(database.schemas, id: \.name) {
                    schema in
                    SchemaRowView(
                        schema: schema,
                        databaseName: database.name,
                        expandedItems: $expandedItems
                    ).padding(.leading, 16)
                }
            }
        }
    }
}

struct SchemaRowView: View {
    let schema: SchemaInfo
    let databaseName: String
    @Binding var expandedItems: Set<String>

    private var schemaKey: String {
        "Schema_\(databaseName)_\(schema.name)"
    }

    private var tablesKey: String {
        "Tables_\(databaseName)_\(schema.name)"
    }

    private var viewsKey: String {
        "Views_\(databaseName)_\(schema.name)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Schema Header
            HStack(spacing: 8) {
                Image(systemName: "folder.fill").foregroundStyle(.orange).font(.system(size: 10)).frame(width: 14)

                Text(schema.name).font(.callout).fontWeight(.medium).foregroundStyle(.primary)

                Spacer()
            }.padding(.horizontal, 32).padding(.vertical, 4)

            // Tables Section
            if !schema.tables.isEmpty {
                DisclosureGroup(
                    isExpanded: Binding(
                        get: {
                            expandedItems.contains(tablesKey)
                        },
                        set: {
                            isExpanded in
                            if isExpanded {
                                expandedItems.insert(tablesKey)
                            } else {
                                expandedItems.remove(tablesKey)
                            }
                        }
                    )
                ) {
                    ForEach(schema.tables, id: \.name) {
                        table in
                        TableRowView(table: table)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "tablecells.fill").foregroundStyle(.blue).font(.system(size: 10)).frame(width: 14)

                        Text("Tables").font(.caption).fontWeight(.medium)

                        Spacer()

                        Text("\(schema.tables.count)").font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 4).padding(.vertical, 1).background(.quaternary, in: Capsule())
                    }.padding(.horizontal, 48).padding(.vertical, 3)
                }
            }

            // Views Section
            if !schema.views.isEmpty {
                DisclosureGroup(
                    isExpanded: Binding(
                        get: {
                            expandedItems.contains(viewsKey)
                        },
                        set: {
                            isExpanded in
                            if isExpanded {
                                expandedItems.insert(viewsKey)
                            } else {
                                expandedItems.remove(viewsKey)
                            }
                        }
                    )
                ) {
                    ForEach(schema.views, id: \.name) {
                        view in
                        ViewRowView(view: view)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.fill").foregroundStyle(.green).font(.system(size: 10)).frame(width: 14)

                        Text("Views").font(.caption).fontWeight(.medium)

                        Spacer()

                        Text("\(schema.views.count)").font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 4).padding(.vertical, 1).background(.quaternary, in: Capsule())
                    }.padding(.horizontal, 48).padding(.vertical, 3)
                }
            }
        }
    }
}

struct TableRowView: View {
    let table: TableInfo

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "tablecells").foregroundStyle(.blue).font(.system(size: 9)).frame(width: 12)

            Text(table.fullName).font(.caption).foregroundStyle(.primary).lineLimit(1)

            Spacer()
        }.padding(.horizontal, 64).padding(.vertical, 2).contentShape(Rectangle()).contextMenu {
            Button("Browse Data") {
                // TODO: Browse table data
            }
            Button("View Structure") {
                // TODO: View table structure
            }
        }
    }
}

struct ViewRowView: View {
    let view: ViewInfo

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye").foregroundStyle(.green).font(.system(size: 9)).frame(width: 12)

            Text(view.fullName).font(.caption).foregroundStyle(.primary).lineLimit(1)

            Spacer()
        }.padding(.horizontal, 64).padding(.vertical, 2).contentShape(Rectangle()).contextMenu {
            Button("Browse Data") {
                // TODO: Browse view data
            }
            Button("View Definition") {
                // TODO: View SQL definition
            }
        }
    }
}

struct ConnectionsView: View {
    let connections: [SavedConnection]
    @Binding var selectedConnectionID: UUID?
    let onAddConnection: () -> Void
    let onDeleteConnection: (UUID) -> Void
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(connections) {
                    connection in
                    ConnectionRowView(
                        connection: connection,
                        isSelected: selectedConnectionID == connection.id,
                        connectionState: appModel.connectionStates[connection.id] ?? .disconnected,
                        onSelect: {
                            selectedConnectionID = connection.id
                        },
                        onConnect: {
                            Task {
                                await appModel.connect(to: connection)
                            }
                        },
                        onEdit: onAddConnection,
                        onDelete: {
                            onDeleteConnection(connection.id)
                        }
                    )
                }

                // Empty state
                if connections.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "plus.circle").font(.system(size: 32)).foregroundStyle(.tertiary)

                        Text("No Connections").font(.headline).foregroundStyle(.secondary)

                        Text("Add your first database connection to get started").font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)

                        Button("Add Connection") {
                            onAddConnection()
                        }.buttonStyle(.borderedProminent).controlSize(.large)
                    }.frame(maxWidth: .infinity).padding(.vertical, 32)
                }
            }.padding(.horizontal, 12).padding(.vertical, 8)
        }
    }
}

struct ConnectionRowView: View {
    let connection: SavedConnection
    let isSelected: Bool
    let connectionState: ConnectionState
    let onSelect: () -> Void
    let onConnect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var statusColor: Color {
        switch connectionState {
        case .connected:
            return .green
        case .connecting, .testing:
            return .orange
        case .error:
            return .red
        case .disconnected:
            return .gray
        }
    }

    private var statusIcon: String {
        switch connectionState {
        case .connected:
            return "checkmark.circle.fill"
        case .connecting, .testing:
            return "clock.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .disconnected:
            return "circle"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Database type icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.blue.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: connection.databaseType.iconName).font(.system(size: 18, weight: .medium)).foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(connection.connectionName).font(.system(.subheadline, weight: .medium)).foregroundStyle(.primary).lineLimit(1)

                    HStack(spacing: 4) {
                        Text(connection.username).font(.caption).foregroundStyle(.secondary)
                        Text("@").font(.caption).foregroundStyle(.tertiary)
                        Text("\(connection.host):\(connection.port)").font(.caption).foregroundStyle(.secondary)
                    }.lineLimit(1)

                    // Database type
                    Text(connection.databaseType.displayName).font(.caption2).foregroundStyle(.tertiary)
                }

                Spacer()

                // Status and actions
                VStack(spacing: 6) {
                    Image(systemName: statusIcon).font(.system(size: 14)).foregroundStyle(statusColor)

                    if !connectionState.isConnected && !connectionState.isLoading {
                        Button("Connect") {
                            onConnect()
                        }.font(.caption2).buttonStyle(.borderless).foregroundStyle(.blue)
                    } else if connectionState.isLoading {
                        ProgressView().controlSize(.mini)
                    }
                }
            }
        }.padding(12).background(
            isSelected ? Color.accentColor.opacity(0.2): Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        ).contentShape(Rectangle()).onTapGesture {
            onSelect()
        }.contextMenu {
            if !connectionState.isConnected {
                Button("Connect") {
                    onConnect()
                }
            }

            Button("Edit Connection") {
                onEdit()
            }

            Divider()

            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}