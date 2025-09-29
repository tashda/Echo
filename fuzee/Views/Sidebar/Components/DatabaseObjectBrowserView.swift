import SwiftUI

struct DatabaseObjectBrowserView: View {
    let database: Database
    let connection: SavedConnection
    @Binding var searchText: String
    @Binding var selectedSchemaName: String?
    @Binding var expandedObjectGroups: Set<SchemaObjectInfo.ObjectType>
    let coordinateSpaceName: String
    let scrollTo: (String, UnitPoint) -> Void

    @EnvironmentObject var appModel: AppModel

    private var filteredSchemas: [SchemaInfo] {
        if let selectedSchemaName = selectedSchemaName {
            return database.schemas.filter { $0.name == selectedSchemaName }
        }
        return database.schemas
    }

    private func filteredObjects(from schema: SchemaInfo, type: SchemaObjectInfo.ObjectType) -> [SchemaObjectInfo] {
        let objects = schema.objects.filter { $0.type == type }

        if searchText.isEmpty {
            return objects
        }

        return objects.filter { object in
            object.name.localizedCaseInsensitiveContains(searchText) ||
            object.fullName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
            ForEach(SchemaObjectInfo.ObjectType.allCases, id: \.self) { objectType in
                let totalObjectsOfType = filteredSchemas.reduce(0) { count, schema in
                    count + filteredObjects(from: schema, type: objectType).count
                }

                if totalObjectsOfType > 0 {
                    Section {
                        if expandedObjectGroups.contains(objectType) {
                            ForEach(filteredSchemas, id: \.name) { schema in
                                let schemaObjects = filteredObjects(from: schema, type: objectType)

                                if !schemaObjects.isEmpty {
                                    if filteredSchemas.count > 1 {
                                        SchemaHeader(schema: schema, objectCount: schemaObjects.count)
                                    }

                                    ForEach(schemaObjects, id: \.id) { object in
                                        DatabaseObjectRow(
                                            object: object,
                                            connection: connection,
                                            showColumns: expandedObjectGroups.contains(objectType)
                                        )
                                        .environmentObject(appModel)
                                    }
                                }
                            }
                        }
                    } header: {
                        StickyHeader(
                            objectType: objectType,
                            count: totalObjectsOfType,
                            isExpanded: expandedObjectGroups.contains(objectType),
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    if expandedObjectGroups.contains(objectType) {
                                        expandedObjectGroups.remove(objectType)
                                    } else {
                                        expandedObjectGroups.insert(objectType)
                                    }
                                }
                            },
                            onHeaderTap: {
                                scrollTo("header-\(objectType.rawValue)", .top)
                            }
                        )
                        .id("header-\(objectType.rawValue)")
                    }
                }
            }
        }
        .onAppear {
            // Initialize expanded groups if empty
            if expandedObjectGroups.isEmpty {
                expandedObjectGroups = Set(SchemaObjectInfo.ObjectType.allCases)
            }
        }
    }
}

// MARK: - Sticky Header
private struct StickyHeader: View {
    let objectType: SchemaObjectInfo.ObjectType
    let count: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    let onHeaderTap: () -> Void

    private var displayName: String {
        switch objectType {
        case .table:
            return "Tables"
        case .view:
            return "Views"
        case .materializedView:
            return "Materialized Views"
        case .function:
            return "Functions"
        case .trigger:
            return "Triggers"
        }
    }

    private var iconName: String {
        switch objectType {
        case .table:
            return "tablecells"
        case .view:
            return "eye"
        case .materializedView:
            return "eye.fill"
        case .function:
            return "function"
        case .trigger:
            return "bolt"
        }
    }

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.blue)

                Text(displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text("(\(count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(
            .regularMaterial,
            in: Rectangle()
        )
        .onTapGesture {
            onHeaderTap()
        }
    }
}

// MARK: - Schema Header
private struct SchemaHeader: View {
    let schema: SchemaInfo
    let objectCount: Int

    var body: some View {
        HStack {
            Image(systemName: "folder")
                .font(.system(size: 12))
                .foregroundStyle(.blue)

            Text(schema.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Text("(\(objectCount))")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(.ultraThickMaterial.opacity(0.5))
    }
}

// MARK: - Database Object Row
private struct DatabaseObjectRow: View {
    let object: SchemaObjectInfo
    let connection: SavedConnection
    let showColumns: Bool

    @EnvironmentObject var appModel: AppModel
    @State private var isExpanded = false
    @State private var isHovered = false

    private var iconName: String {
        switch object.type {
        case .table:
            return "tablecells"
        case .view:
            return "eye"
        case .materializedView:
            return "eye.fill"
        case .function:
            return "function"
        case .trigger:
            return "bolt"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            Button {
                if !object.columns.isEmpty {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if !object.columns.isEmpty {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                    } else {
                        Spacer().frame(width: 12)
                    }

                    Image(systemName: iconName)
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)

                    Text(object.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    if !object.columns.isEmpty {
                        Text("\(object.columns.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.regularMaterial, in: Capsule())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? .selection.opacity(0.5) : .clear)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            .contextMenu {
                Button("Query Data") {
                    queryObjectData()
                }

                Button("View Structure") {
                    viewObjectStructure()
                }

                if object.type == .table {
                    Button("Insert Row") {
                        insertRowIntoTable()
                    }
                }
            }

            // Columns (if expanded)
            if isExpanded && !object.columns.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(object.columns, id: \.name) { column in
                        HStack(spacing: 8) {
                            Spacer().frame(width: 40)

                            Image(systemName: column.isPrimaryKey ? "key.fill" : "doc.text")
                                .font(.system(size: 10))
                                .foregroundStyle(column.isPrimaryKey ? .yellow : .secondary)

                            Text(column.name)
                                .font(.caption)
                                .foregroundStyle(.primary)

                            Text(column.dataType)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.regularMaterial, in: Capsule())

                            if !column.isNullable {
                                Text("NOT NULL")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                    .fontWeight(.medium)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 1)
                    }
                }
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }

    private func queryObjectData() {
        // Implement query data functionality
        Task { @MainActor in
            await appModel.executeQuery("SELECT * FROM \(object.fullName) LIMIT 100;")
        }
    }

    private func viewObjectStructure() {
        // Implement view structure functionality
        Task { @MainActor in
            await appModel.executeQuery("\\d \(object.fullName)")
        }
    }

    private func insertRowIntoTable() {
        // Implement insert row functionality
        let columnNames = object.columns.map { $0.name }.joined(separator: ", ")
        let placeholders = object.columns.map { _ in "?" }.joined(separator: ", ")
        let insertQuery = "INSERT INTO \(object.fullName) (\(columnNames)) VALUES (\(placeholders));"

        Task { @MainActor in
            await appModel.executeQuery(insertQuery)
        }
    }
}

#Preview {
    DatabaseObjectBrowserView(
        database: DatabaseInfo(
            name: "test_db",
            schemas: [
                SchemaInfo(name: "public", objects: [
                    SchemaObjectInfo(name: "users", schema: "public", type: .table),
                    SchemaObjectInfo(name: "orders", schema: "public", type: .table),
                    SchemaObjectInfo(name: "user_view", schema: "public", type: .view)
                ])
            ]
        ),
        connection: SavedConnection(
            id: UUID(),
            connectionName: "Test Connection",
            host: "localhost",
            port: 5432,
            databaseName: "test_db",
            username: "test_user",
            databaseType: .postgresql
        ),
        searchText: .constant(""),
        selectedSchemaName: .constant(nil),
        expandedObjectGroups: .constant(Set(SchemaObjectInfo.ObjectType.allCases)),
        coordinateSpaceName: "test",
        scrollTo: { _, _ in }
    )
}