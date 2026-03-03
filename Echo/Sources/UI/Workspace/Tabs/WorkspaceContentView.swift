import SwiftUI
import EchoSense
#if os(macOS)
import AppKit
#endif

fileprivate typealias ForeignKeyMapping = [String: ColumnInfo.ForeignKeyReference]

#if os(macOS)
private func buildForeignKeyMapping(from details: TableStructureDetails) -> ForeignKeyMapping {
    var mapping: ForeignKeyMapping = [:]
    for foreignKey in details.foreignKeys {
        guard foreignKey.columns.count == foreignKey.referencedColumns.count,
              foreignKey.columns.count == 1,
              let localColumn = foreignKey.columns.first,
              let referencedColumn = foreignKey.referencedColumns.first else { continue }

        let reference = ColumnInfo.ForeignKeyReference(
            constraintName: foreignKey.name,
            referencedSchema: foreignKey.referencedSchema,
            referencedTable: foreignKey.referencedTable,
            referencedColumn: referencedColumn
        )
        mapping[localColumn.lowercased()] = reference
    }
    return mapping
}
#endif

struct WorkspaceContentView: View {
    @ObservedObject var tab: WorkspaceTab
    let runQuery: (String) async -> Void
    let cancelQuery: () -> Void
    let gridStateProvider: () -> QueryResultsGridState
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            ColorTokens.Background.primary
                .ignoresSafeArea()

            Group {
                if let structureEditor = tab.structureEditor {
                    TableStructureEditorView(tab: tab, viewModel: structureEditor)
                        .background(ColorTokens.Background.primary)
                } else if let diagram = tab.diagram {
                    SchemaDiagramView(viewModel: diagram)
                        .background(ColorTokens.Background.primary)
                } else if let jobs = tab.jobManagement {
                    JobManagementView(viewModel: jobs)
                        .background(ColorTokens.Background.primary)
                } else if let query = tab.query {
                    QueryEditorContainer(
                        tab: tab,
                        query: query,
                        runQuery: runQuery,
                        cancelQuery: cancelQuery,
                        gridStateProvider: gridStateProvider
                    )
                } else {
                    EmptyView()
                }
            }
        }
    }
}

struct QueryEditorContainer: View {
    @ObservedObject var tab: WorkspaceTab
    @ObservedObject var query: QueryEditorState
    let runQuery: (String) async -> Void
    let cancelQuery: () -> Void
    let gridStateProvider: () -> QueryResultsGridState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState

    private let minRatio: CGFloat = 0.25
    private let maxRatio: CGFloat = 0.8
    @State private var liveSplitRatioOverride: CGFloat?
#if os(macOS)
    @State private var latestForeignKeySelection: QueryResultsTableView.ForeignKeySelection?
    @State private var latestJsonSelection: QueryResultsTableView.JsonSelection?
    @State private var foreignKeyFetchTask: Task<Void, Never>?
    @State private var autoOpenedInspector = false
#endif

    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let backgroundColor = ColorTokens.Background.primary
            let shouldShowResultsOnly = query.isResultsOnly
            let ratioBinding = Binding<CGFloat>(
                get: { min(max(query.splitRatio, minRatio), maxRatio) },
                set: { newValue in
                    query.splitRatio = min(max(newValue, minRatio), maxRatio)
                }
            )
            let baseRatio = ratioBinding.wrappedValue
            let effectiveRatio = min(max(liveSplitRatioOverride ?? baseRatio, minRatio), maxRatio)
            let isResizingResults = liveSplitRatioOverride != nil

            VStack(spacing: 0) {
                if shouldShowResultsOnly {
#if os(macOS)
                QueryResultsSection(
                    query: query,
                    connection: connectionForDisplay,
                    activeDatabaseName: connectionDatabaseName,
                    gridState: gridStateProvider(),
                    isResizingResults: isResizingResults,
                    foreignKeyDisplayMode: foreignKeyDisplayMode,
                    foreignKeyInspectorBehavior: foreignKeyInspectorBehavior,
                    onForeignKeyEvent: handleForeignKeyEvent,
                    onJsonEvent: handleJsonEvent
                )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(backgroundColor)
                        .transition(.opacity)
                #else
                    QueryResultsSection(
                        query: query,
                        connection: connectionForDisplay,
                        activeDatabaseName: connectionDatabaseName,
                        gridState: gridStateProvider(),
                        isResizingResults: isResizingResults
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(backgroundColor)
                        .transition(.opacity)
                #endif
                } else {
                    QueryInputSection(
                        query: query,
                        onExecute: { sql in await runQuery(sql) },
                        onCancel: cancelQuery,
                        onAddBookmark: handleBookmarkRequest,
                        completionContext: editorCompletionContext
                    )
                    .frame(height: query.hasExecutedAtLeastOnce ? totalHeight * effectiveRatio : totalHeight)
                    .background(backgroundColor)

                    if query.hasExecutedAtLeastOnce {
                        ResizeHandle(
                            ratio: effectiveRatio,
                            minRatio: minRatio,
                            maxRatio: maxRatio,
                            availableHeight: totalHeight,
                            onLiveUpdate: { proposed in
                                liveSplitRatioOverride = proposed
                            },
                            onCommit: { proposed in
                                let clamped = min(max(proposed, minRatio), maxRatio)
                                liveSplitRatioOverride = nil
                                if abs(ratioBinding.wrappedValue - clamped) > 0.0001 {
                                    ratioBinding.wrappedValue = clamped
                                }
                            }
                        )

                    #if os(macOS)
                        QueryResultsSection(
                            query: query,
                            connection: connectionForDisplay,
                            activeDatabaseName: connectionDatabaseName,
                            gridState: gridStateProvider(),
                            isResizingResults: isResizingResults,
                            foreignKeyDisplayMode: foreignKeyDisplayMode,
                            foreignKeyInspectorBehavior: foreignKeyInspectorBehavior,
                            onForeignKeyEvent: handleForeignKeyEvent,
                            onJsonEvent: handleJsonEvent
                        )
                            .frame(height: totalHeight * (1 - effectiveRatio))
                            .background(backgroundColor)
                            .transition(.opacity)
                    #else
                        QueryResultsSection(
                            query: query,
                            connection: connectionForDisplay,
                            activeDatabaseName: connectionDatabaseName,
                            gridState: gridStateProvider(),
                            isResizingResults: isResizingResults
                        )
                            .frame(height: totalHeight * (1 - effectiveRatio))
                            .background(backgroundColor)
                            .transition(.opacity)
                    #endif
                    }
                }
            }
        }
        .background(ColorTokens.Background.primary)
        .onAppear {
            updateClipboardContext()
        }
        .onChange(of: tab.connection.metadataColorHex) { _, _ in
            updateClipboardContext()
        }
        .onChange(of: tab.connection.database) { _, _ in
            updateClipboardContext()
        }
        .onChange(of: query.isResultsOnly) { _, _ in
            liveSplitRatioOverride = nil
        }
        .onChange(of: query.hasExecutedAtLeastOnce) { _, executed in
            if !executed {
                liveSplitRatioOverride = nil
            }
        }
        .task {
            await triggerAutoExecutionIfNeeded()
        }
        .onChange(of: query.shouldAutoExecuteOnAppear) { _, newValue in
            guard newValue else { return }
            Task {
                await triggerAutoExecutionIfNeeded()
            }
        }
    }

    private var connectionSession: ConnectionSession? {
        appModel.sessionManager.activeSessions.first { $0.id == tab.connectionSessionID }
    }

    private var connectionServerName: String? {
        let name = (connectionSession?.connection.connectionName ?? tab.connection.connectionName)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        let host = (connectionSession?.connection.host ?? tab.connection.host)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return host.isEmpty ? nil : host
    }

    private var connectionDatabaseName: String? {
        if let selected = connectionSession?.selectedDatabaseName?.trimmingCharacters(in: .whitespacesAndNewlines), !selected.isEmpty {
            return selected
        }
        let database = tab.connection.database.trimmingCharacters(in: .whitespacesAndNewlines)
        return database.isEmpty ? nil : database
    }

#if os(macOS)
    private var foreignKeyDisplayMode: ForeignKeyDisplayMode {
        appModel.globalSettings.foreignKeyDisplayMode
    }

    private var foreignKeyInspectorBehavior: ForeignKeyInspectorBehavior {
        appModel.globalSettings.foreignKeyInspectorBehavior
    }

    private var includeRelatedForeignKeys: Bool {
        appModel.globalSettings.foreignKeyIncludeRelated
    }
#endif

    @MainActor
    private func triggerAutoExecutionIfNeeded() async {
        guard query.shouldAutoExecuteOnAppear else { return }
        guard !query.isExecuting else { return }
        query.shouldAutoExecuteOnAppear = false
        await runQuery(query.sql)
    }

    private func updateClipboardContext() {
        query.updateClipboardContext(
            serverName: connectionServerName,
            databaseName: connectionDatabaseName,
            connectionColorHex: connectionColorHex
        )
    }

    private var connectionServerVersion: String? {
        let candidates: [String?] = [
            connectionSession?.databaseStructure?.serverVersion,
            connectionSession?.connection.serverVersion,
            tab.connection.serverVersion
        ]
        for candidate in candidates {
            if let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private var connectionForDisplay: SavedConnection {
        var snapshot = connectionSession?.connection ?? tab.connection
        snapshot.serverVersion = connectionServerVersion
        return snapshot
    }

    private var connectionColorHex: String? {
        if let sessionHex = connectionSession?.connection.metadataColorHex {
            return sessionHex
        }
        return tab.connection.metadataColorHex
    }

    private var editorCompletionContext: SQLEditorCompletionContext? {
        let session = connectionSession
        let baseConnection = session?.connection ?? tab.connection
        let databaseType = EchoSenseDatabaseType(baseConnection.databaseType)
        let selectedDatabase = normalized(session?.selectedDatabaseName)
            ?? normalized(baseConnection.database)
        let structure = session?.databaseStructure
            ?? session?.connection.cachedStructure
            ?? tab.connection.cachedStructure
        let defaultSchema = defaultSchema(for: databaseType)

        return SQLEditorCompletionContext(
            databaseType: databaseType,
            selectedDatabase: selectedDatabase,
            defaultSchema: defaultSchema,
            structure: structure.flatMap { EchoSenseBridge.makeStructure(from: $0) }
        )
    }

    private func defaultSchema(for type: EchoSenseDatabaseType) -> String? {
        switch type {
        case .microsoftSQL:
            return "dbo"
        case .postgresql:
            return "public"
        case .mysql, .sqlite:
            return nil
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

#if os(macOS)
    private func handleForeignKeyEvent(_ event: QueryResultsTableView.ForeignKeyEvent) {
        switch event {
        case .selectionChanged(let selection):
            latestForeignKeySelection = selection
            if selection != nil {
                latestJsonSelection = nil
            }
            if let selection {
                if shouldAutoActivate(for: selection, triggeredByIcon: false) {
                    performForeignKeyActivation(for: selection)
                } else {
                    if foreignKeyDisplayMode == .showInspector,
                       foreignKeyInspectorBehavior == .respectInspectorVisibility,
                       !appState.showInfoSidebar {
                        if case .foreignKey = appModel.dataInspectorContent {
                            appModel.dataInspectorContent = nil
                        }
                    }
                }
            } else {
                foreignKeyFetchTask?.cancel()
                foreignKeyFetchTask = nil
                if case .foreignKey = appModel.dataInspectorContent {
                    appModel.dataInspectorContent = nil
                }
                if foreignKeyInspectorBehavior == .autoOpenAndClose && autoOpenedInspector {
                    autoOpenedInspector = false
                    if appState.showInfoSidebar {
                        appState.showInfoSidebar = false
                    }
                }
            }
        case .requestMetadata:
            guard foreignKeyDisplayMode != .disabled else { return }
            guard let context = query.beginForeignKeyMappingFetch() else { return }
            Task(priority: .utility) {
                let mapping = await loadForeignKeyMapping(schema: context.schema, table: context.table)
                await MainActor.run {
                    if Task.isCancelled {
                        query.failForeignKeyMappingFetch()
                    } else {
                        query.completeForeignKeyMappingFetch(with: mapping)
                    }
                }
            }

        case .activate(let selection):
            performForeignKeyActivation(for: selection)
        }
    }

    private func handleJsonEvent(_ event: QueryResultsTableView.JsonCellEvent) {
        switch event {
        case .selectionChanged(let selection):
            latestJsonSelection = selection
            if let selection {
                let content = makeJsonInspectorContent(for: selection)
                appModel.dataInspectorContent = .json(content)
            } else if case .json = appModel.dataInspectorContent {
                appModel.dataInspectorContent = nil
            }
        case .activate(let selection):
            latestJsonSelection = selection
            let content = makeJsonInspectorContent(for: selection)
            appModel.dataInspectorContent = .json(content)
        }
    }

    private func shouldAutoActivate(for selection: QueryResultsTableView.ForeignKeySelection, triggeredByIcon: Bool) -> Bool {
        guard foreignKeyDisplayMode != .disabled else { return false }
        switch foreignKeyDisplayMode {
        case .showInspector:
            if foreignKeyInspectorBehavior == .autoOpenAndClose {
                return true
            }
            return appState.showInfoSidebar
        case .showIcon:
            if foreignKeyInspectorBehavior == .autoOpenAndClose {
                return true
            }
            return triggeredByIcon
        case .disabled:
            return false
        }
    }

    private func performForeignKeyActivation(for selection: QueryResultsTableView.ForeignKeySelection) {
        guard foreignKeyDisplayMode != .disabled else { return }

        foreignKeyFetchTask?.cancel()

        foreignKeyFetchTask = Task {
            if foreignKeyInspectorBehavior == .autoOpenAndClose {
                await MainActor.run {
                    if !appState.showInfoSidebar {
                        appState.showInfoSidebar = true
                        autoOpenedInspector = true
                    }
                }
            }

            guard let content = await fetchForeignKeyInspectorContent(for: selection, includeRelated: includeRelatedForeignKeys, depth: 0) else {
                await MainActor.run {
                    if case .foreignKey = appModel.dataInspectorContent {
                        appModel.dataInspectorContent = nil
                    }
                }
                return
            }

            await MainActor.run {
                appModel.dataInspectorContent = .foreignKey(content)
            }
        }
    }

    private func fetchForeignKeyInspectorContent(for selection: QueryResultsTableView.ForeignKeySelection, includeRelated: Bool, depth: Int) async -> ForeignKeyInspectorContent? {
        guard let lookupQuery = makeForeignKeyLookupQuery(for: selection, includeLimit: true) else { return nil }
        let detailQuery = makeForeignKeyLookupQuery(for: selection, includeLimit: false)
        do {
            let result = try await tab.session.simpleQuery(lookupQuery)
            guard let row = result.rows.first else { return nil }

            var fields: [ForeignKeyInspectorContent.Field] = []
            for (column, value) in zip(result.columns, row) {
                let displayValue = value ?? "NULL"
                fields.append(ForeignKeyInspectorContent.Field(label: column.name, value: displayValue))
            }

            let title = selection.reference.referencedTable
            let subtitle = selection.reference.referencedSchema.trimmingCharacters(in: .whitespacesAndNewlines)
            var related: [ForeignKeyInspectorContent] = []

            if includeRelated, depth < 1 {
                let mapping = await loadForeignKeyMapping(schema: selection.reference.referencedSchema, table: selection.reference.referencedTable)
                if !mapping.isEmpty {
                    related = await loadRelatedForeignKeyContent(mapping: mapping, baseRow: row, columns: result.columns, parentDepth: depth)
                }
            }

            return ForeignKeyInspectorContent(
                title: title,
                subtitle: subtitle.isEmpty ? nil : subtitle,
                fields: fields,
                related: related,
                lookupQuerySQL: detailQuery ?? lookupQuery
            )
        } catch {
            return nil
        }
    }

    private func loadRelatedForeignKeyContent(mapping: ForeignKeyMapping, baseRow: [String?], columns: [ColumnInfo], parentDepth: Int) async -> [ForeignKeyInspectorContent] {
        var related: [ForeignKeyInspectorContent] = []
        for (index, column) in columns.enumerated() {
            guard let reference = mapping[column.name.lowercased()] else { continue }
            guard index < baseRow.count, let raw = baseRow[index] else { continue }

            let trimmedValue = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedValue.isEmpty else { continue }

            let selection = QueryResultsTableView.ForeignKeySelection(
                row: 0,
                column: index,
                value: trimmedValue,
                columnName: column.name,
                reference: reference,
                valueKind: ResultGridValueClassifier.kind(forDataType: column.dataType, value: trimmedValue)
            )

            if let nested = await fetchForeignKeyInspectorContent(for: selection, includeRelated: includeRelatedForeignKeys, depth: parentDepth + 1) {
                related.append(nested)
            }
        }
        return related
    }

    private func loadForeignKeyMapping(schema: String, table: String) async -> ForeignKeyMapping {
        do {
            let details = try await tab.session.getTableStructureDetails(schema: schema, table: table)
            return buildForeignKeyMapping(from: details)
        } catch {
            return [:]
        }
    }

    private func makeForeignKeyLookupQuery(for selection: QueryResultsTableView.ForeignKeySelection, includeLimit: Bool) -> String? {
        let databaseType = tab.connection.databaseType
        guard let literal = makeForeignKeyLiteral(for: selection, databaseType: databaseType) else { return nil }
        let reference = selection.reference
        let tableIdentifier = qualifiedTable(schema: reference.referencedSchema, table: reference.referencedTable, databaseType: databaseType)
        let columnIdentifier = quoteIdentifier(reference.referencedColumn, databaseType: databaseType)

        switch databaseType {
        case .microsoftSQL:
            if includeLimit {
                return "SELECT TOP 1 * FROM \(tableIdentifier) WHERE \(columnIdentifier) = \(literal);"
            } else {
                return "SELECT * FROM \(tableIdentifier) WHERE \(columnIdentifier) = \(literal);"
            }
        default:
            if includeLimit {
                return "SELECT * FROM \(tableIdentifier) WHERE \(columnIdentifier) = \(literal) LIMIT 1;"
            } else {
                return "SELECT * FROM \(tableIdentifier) WHERE \(columnIdentifier) = \(literal);"
            }
        }
    }

    private func qualifiedTable(schema: String, table: String, databaseType: DatabaseType) -> String {
        let trimmedSchema = schema.trimmingCharacters(in: .whitespacesAndNewlines)
        let tablePart = quoteIdentifier(table, databaseType: databaseType)
        guard !trimmedSchema.isEmpty else { return tablePart }
        return "\(quoteIdentifier(trimmedSchema, databaseType: databaseType)).\(tablePart)"
    }

    private func quoteIdentifier(_ identifier: String, databaseType: DatabaseType) -> String {
        switch databaseType {
        case .postgresql, .sqlite:
            let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        case .mysql:
            let escaped = identifier.replacingOccurrences(of: "`", with: "``")
            return "`\(escaped)`"
        case .microsoftSQL:
            let escaped = identifier.replacingOccurrences(of: "]", with: "]]")
            return "[\(escaped)]"
        }
    }

    private func makeForeignKeyLiteral(for selection: QueryResultsTableView.ForeignKeySelection, databaseType: DatabaseType) -> String? {
        let rawValue = selection.value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch selection.valueKind {
        case .numeric:
            return rawValue.isEmpty ? nil : rawValue
        case .boolean:
            let normalized = rawValue.lowercased()
            let truthy: Set<String> = ["true", "t", "1", "yes", "y"]
            let isTrue = truthy.contains(normalized)
            switch databaseType {
            case .mysql, .microsoftSQL:
                return isTrue ? "1" : "0"
            case .postgresql, .sqlite:
                return isTrue ? "TRUE" : "FALSE"
            }
        default:
            let escaped = rawValue.replacingOccurrences(of: "'", with: "''")
            return "'\(escaped)'"
        }
    }
#endif

    private func makeJsonInspectorContent(for selection: QueryResultsTableView.JsonSelection) -> JsonInspectorContent {
        let outline = selection.jsonValue.toOutlineNode()
        let subtitle = jsonRowSummary(for: selection)
        return JsonInspectorContent(title: selection.columnName, subtitle: subtitle, outline: outline)
    }

    private func jsonRowSummary(for selection: QueryResultsTableView.JsonSelection) -> String {
        if let descriptor = primaryKeyDescriptor(for: selection) {
            return descriptor
        }
        return "Row \(selection.displayedRowIndex + 1)"
    }

    private func primaryKeyDescriptor(for selection: QueryResultsTableView.JsonSelection) -> String? {
        guard let index = query.displayedColumns.firstIndex(where: { $0.isPrimaryKey }),
              index < query.displayedColumns.count else {
            return nil
        }
        let column = query.displayedColumns[index]
        guard let raw = query.valueForDisplay(row: selection.sourceRowIndex, column: index) else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return "\(column.name): \(trimmed)"
    }

    private func handleBookmarkRequest(_ sql: String) {
        Task {
            await appModel.addBookmark(
                for: tab.connection,
                databaseName: connectionDatabaseName,
                title: tabTitleForBookmark,
                query: sql,
                source: .queryEditorSelection
            )
        }
    }

    private var tabTitleForBookmark: String? {
        let trimmed = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct ResizeHandle: View {
    let ratio: CGFloat
    let minRatio: CGFloat
    let maxRatio: CGFloat
    let availableHeight: CGFloat
    let onLiveUpdate: (CGFloat) -> Void
    let onCommit: (CGFloat) -> Void

    @State private var dragStartRatio: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 2)
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 60, height: 3)
        }
        .frame(height: 8)
        .background(Color.clear)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDragging {
                        dragStartRatio = ratio
                        isDragging = true
                    }

                    let delta = value.translation.height / max(availableHeight, 1)
                    let proposed = min(max(dragStartRatio + delta, minRatio), maxRatio)
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        onLiveUpdate(proposed)
                    }
                }
                .onEnded { value in
                    let delta = value.translation.height / max(availableHeight, 1)
                    let proposed = min(max(dragStartRatio + delta, minRatio), maxRatio)
                    isDragging = false
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        onCommit(proposed)
                    }
                }
        )
#if os(macOS)
        .onHover { hovering in
            if hovering {
                NSCursor.resizeUpDown.set()
            } else {
                NSCursor.arrow.set()
            }
        }
#endif
    }
}
