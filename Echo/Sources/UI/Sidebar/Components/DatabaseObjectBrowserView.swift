import SwiftUI

/// Database Explorer – hierarchical object list rendered in the explorer sidebar.
struct DatabaseObjectBrowserView: View {
    let database: DatabaseInfo
    let connection: SavedConnection
    @Binding var searchText: String
    @Binding var selectedSchemaName: String?
    @Binding var expandedObjectGroups: Set<SchemaObjectInfo.ObjectType>
    @Binding var expandedObjectIDs: Set<String>
    let scrollTo: (String, UnitPoint) -> Void

    @EnvironmentObject private var appModel: AppModel

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool { !trimmedSearchText.isEmpty }

    private var totalFilteredObjectCount: Int {
        SchemaObjectInfo.ObjectType.allCases.reduce(into: 0) { result, type in
            result += objects(for: type).count
        }
    }

    private var filteredSchemas: [SchemaInfo] {
        if let selectedSchemaName {
            return database.schemas.filter { $0.name == selectedSchemaName }
        }
        return database.schemas
    }

    private func objects(for type: SchemaObjectInfo.ObjectType) -> [SchemaObjectInfo] {
        filteredSchemas
            .flatMap { schema in
                schema.objects.filter { object in
                    object.type == type && matchesSearch(object)
                }
            }
            .sorted { lhs, rhs in
                lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
            }
    }

    private func matchesSearch(_ object: SchemaObjectInfo) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return object.name.localizedCaseInsensitiveContains(query) ||
            object.schema.localizedCaseInsensitiveContains(query) ||
            object.fullName.localizedCaseInsensitiveContains(query)
    }

    private func displayName(for object: SchemaObjectInfo) -> String {
        if selectedSchemaName == nil {
            return object.fullName
        }
        return object.name
    }

    private func expansionBinding(for objectID: String) -> Binding<Bool> {
        Binding(
            get: { expandedObjectIDs.contains(objectID) },
            set: { newValue in
                if newValue {
                    expandedObjectIDs.insert(objectID)
                } else {
                    expandedObjectIDs.remove(objectID)
                }
            }
        )
    }

    private func revealTable(fullName: String) {
        guard let target = database.schemas
            .flatMap({ $0.objects.filter { $0.type == .table } })
            .first(where: { $0.fullName == fullName }) else { return }

        if let selected = selectedSchemaName {
            if selected != target.schema {
                selectedSchemaName = nil
            }
        }

        expandedObjectGroups.insert(.table)
        expandedObjectIDs.insert(target.id)

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.28)) {
                scrollTo(target.id, UnitPoint(x: 0.5, y: 0.2))
            }
        }
    }

    var body: some View {
        if isSearching && totalFilteredObjectCount == 0 {
            SearchEmptyStateView(query: searchText)
        } else {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(SchemaObjectInfo.ObjectType.allCases, id: \.self) { objectType in
                    let objects = objects(for: objectType)

                    let headerID = "header-\(objectType.rawValue)"
                    let isExpanded = expandedObjectGroups.contains(objectType)

                    VStack(alignment: .leading, spacing: 4) {
                        Button {
                            let wasExpanded = isExpanded
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if wasExpanded {
                                    expandedObjectGroups.remove(objectType)
                                } else {
                                    expandedObjectGroups.insert(objectType)
                                }
                            }
                            if wasExpanded {
                                scrollTo(headerID, .top)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(objectType.pluralDisplayName.uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text("\(objects.count)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary.opacity(0.8))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.primary.opacity(0.06), in: Capsule())
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if isExpanded {
                            ForEach(objects, id: \.id) { object in
                                DatabaseObjectRow(
                                    object: object,
                                    displayName: displayName(for: object),
                                    connection: connection,
                                    showColumns: object.type == .table || object.type == .view || object.type == .materializedView,
                                    isExpanded: expansionBinding(for: object.id),
                                    onTriggerTableTap: object.type == .trigger ? { tableName in revealTable(fullName: tableName) } : nil
                                )
                                .environmentObject(appModel)
                                .id(object.id)
                            }
                        }
                    }
                    .id(headerID)
                }
            }
        }
    }

// MARK: - Search Empty State

private struct SearchEmptyStateView: View {
    let query: String

    private var formattedQuery: String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "your search" }
        return "\"\(trimmed)\""
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text("Nothing found for \(formattedQuery)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Try adjusting your filters or search terms.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Database Object Row

private struct DatabaseObjectRow: View {
    let object: SchemaObjectInfo
    let displayName: String
    let connection: SavedConnection
    let showColumns: Bool
    @Binding var isExpanded: Bool
    let onTriggerTableTap: ((String) -> Void)?

    @EnvironmentObject private var appModel: AppModel
    @State private var isHovered = false

    private var canExpand: Bool {
        showColumns && !object.columns.isEmpty
    }

    private var accentColor: Color {
        appModel.useServerColorAsAccent ? connection.color : Color.accentColor
    }

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
            rowContent

            if isExpanded && canExpand {
                columnsList
            }
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: object.type == .trigger ? 6 : 0) {
            HStack(spacing: 8) {
                if canExpand {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                } else {
                    Spacer().frame(width: 12)
                }

                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(accentColor)

                Text(displayName)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if showColumns && !object.columns.isEmpty {
                    Text("\(object.columns.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(0.12), in: Capsule())
                }
            }

            if object.type == .trigger {
                triggerMetadata
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(highlightBackground)
        .shadow(color: isHovered ? accentColor.opacity(0.15) : Color.clear, radius: 8, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            guard canExpand else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu { contextMenuContent }
    }

    @ViewBuilder
    private var triggerMetadata: some View {
        HStack(spacing: 6) {
            if let action = object.triggerAction, !action.isEmpty {
                Text(action)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accentColor.opacity(0.12), in: Capsule())
            }
            if let table = object.triggerTable, !table.isEmpty {
                Button {
                    onTriggerTableTap?(table)
                } label: {
                    Text(table)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accentColor.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.leading, 24)
    }

    @ViewBuilder
    private var highlightBackground: some View {
        let base = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if isHovered || isExpanded {
            base
                .fill(accentColor.opacity(0.12))
                .overlay(
                    base.stroke(accentColor.opacity(0.35), lineWidth: 1)
                )
        } else {
            Color.clear
        }
    }

    private var columnsList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(object.columns, id: \.name) { column in
                HStack(spacing: 8) {
                    Spacer().frame(width: 24)
                    Image(systemName: column.isPrimaryKey ? "key.fill" : "doc.text")
                        .font(.system(size: 10))
                        .foregroundStyle(column.isPrimaryKey ? accentColor : .secondary)
                    Text(column.name)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(formatDataType(column.dataType))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(0.1), in: Capsule())
                }
                .padding(.vertical, 1)
                .padding(.trailing, 12)
            }
        }
        .padding(.bottom, 4)
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
    }

    private func formatDataType(_ dataType: String) -> String {
        var formatted = dataType

        // Replace "with time zone" with "tz"
        if formatted.contains("with time zone") {
            formatted = formatted.replacingOccurrences(of: " with time zone", with: "tz")
        }

        // Remove "without time zone"
        if formatted.contains("without time zone") {
            formatted = formatted.replacingOccurrences(of: " without time zone", with: "")
        }

        return formatted
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            queryObjectData()
        } label: {
            Label("Query Data", systemImage: "tablecells")
        }
        Button {
            viewObjectStructure()
        } label: {
            Label("View Structure", systemImage: "square.stack.3d.up")
        }
        if object.type == .table {
            Button {
                insertRowIntoTable()
            } label: {
                Label("Insert Row", systemImage: "square.and.pencil")
            }
        }
    }

    private func queryObjectData() {
        let sql = "SELECT * FROM \(object.fullName) LIMIT 100;"
        Task { @MainActor in
            guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
            appModel.openQueryTab(for: session, presetQuery: sql)
        }
    }

    private func viewObjectStructure() {
        Task { @MainActor in
            guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
            appModel.openStructureTab(for: session, object: object)
        }
    }

    private func insertRowIntoTable() {
        guard object.type == .table else { return }
        let columnNames = object.columns.map { "\"\($0.name)\"" }.joined(separator: ", ")
        let values = object.columns.map { _ in "?" }.joined(separator: ", ")
        let sql = "INSERT INTO \(object.fullName) (\(columnNames)) VALUES (\(values));"
        Task { @MainActor in
            do {
                _ = try await appModel.executeUpdate(sql)
            } catch {
                print("Insert failed: \(error)")
            }
        }
    }
}
}
