import SwiftUI
import SQLServerKit

struct PermissionManagerSearchSheet: View {
    @Bindable var viewModel: PermissionManagerViewModel
    let session: ConnectionSession
    let onDismiss: () -> Void

    @State private var objectTypeFilter: ObjectTypeFilter = .all
    @State private var searchText = ""
    @State private var searchResults: [SearchResultItem] = []
    @State private var selectedResults: Set<String> = []
    @State private var isSearching = false

    var body: some View {
        SheetLayoutCustomFooter(title: "Add Securables") {
            VStack(spacing: 0) {
                filterBar
                Divider()
                resultsList
            }
        } footer: {
            Text("\(selectedResults.count) selected")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)

            Spacer()

            Button("Cancel") { onDismiss() }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

            if !selectedResults.isEmpty {
                Button("Add Selected") {
                    addSelectedSecurables()
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Add Selected") {}
                    .buttonStyle(.bordered)
                    .disabled(true)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(minWidth: 480, minHeight: 360)
        .frame(idealWidth: 520, idealHeight: 400)
        .task { await performSearch() }
    }

    // MARK: - Filters

    private var filterBar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Picker("Type", selection: $objectTypeFilter) {
                ForEach(ObjectTypeFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)

            TextField("Search", text: $searchText, prompt: Text("Filter by name\u{2026}"))
                .textFieldStyle(.roundedBorder)

            Button("Search") {
                Task { await performSearch() }
            }
            .buttonStyle(.bordered)
        }
        .padding(SpacingTokens.sm)
        .onChange(of: objectTypeFilter) { _, _ in
            Task { await performSearch() }
        }
    }

    // MARK: - Results

    private var resultsList: some View {
        Group {
            if isSearching {
                VStack {
                    Spacer()
                    ProgressView("Searching\u{2026}")
                    Spacer()
                }
            } else if searchResults.isEmpty {
                VStack {
                    Spacer()
                    Text("No objects found.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Spacer()
                }
            } else {
                Table(filteredResults, selection: $selectedResults) {
                    TableColumn("Name") { item in
                        Text(item.name)
                            .font(TypographyTokens.Table.name)
                    }

                    TableColumn("Schema") { item in
                        Text(item.schema)
                            .font(TypographyTokens.Table.secondaryName)
                    }
                    .width(min: 60, ideal: 80)

                    TableColumn("Type") { item in
                        Text(item.typeName)
                            .font(TypographyTokens.Table.secondaryName)
                    }
                    .width(min: 60, ideal: 80)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredResults: [SearchResultItem] {
        guard !searchText.isEmpty else { return searchResults }
        return searchResults.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Search

    private func performSearch() async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isSearching = true
        defer { isSearching = false }

        do {
            _ = try? await session.session.sessionForDatabase(viewModel.databaseName)
            var results: [SearchResultItem] = []

            // Database-level securable
            if objectTypeFilter == .all {
                results.append(SearchResultItem(
                    id: "DATABASE:\(viewModel.databaseName)",
                    name: viewModel.databaseName,
                    schema: "",
                    typeName: "Database",
                    objectKind: nil
                ))
            }

            if objectTypeFilter == .all || objectTypeFilter == .tables || objectTypeFilter == .views {
                let allObjects = try await mssql.metadata.listTables()
                for obj in allObjects {
                    let kind = obj.kind
                    if objectTypeFilter == .tables && kind != .table { continue }
                    if objectTypeFilter == .views && kind != .view { continue }
                    if kind == .systemTable || kind == .tableType { continue }
                    let typeName = kind == .view ? "View" : "Table"
                    let objKind: ObjectKind = kind == .view ? .view : .table
                    results.append(SearchResultItem(
                        id: "\(typeName.uppercased()):\(obj.schema).\(obj.name)",
                        name: obj.name,
                        schema: obj.schema,
                        typeName: typeName,
                        objectKind: objKind
                    ))
                }
            }

            if objectTypeFilter == .all || objectTypeFilter == .schemas {
                let schemas = try await mssql.security.listSchemas()
                results.append(contentsOf: schemas.map {
                    SearchResultItem(
                        id: "SCHEMA:\($0.name)",
                        name: $0.name,
                        schema: "",
                        typeName: "Schema",
                        objectKind: nil
                    )
                })
            }

            searchResults = results.sorted { $0.name < $1.name }
        } catch { }
    }

    // MARK: - Add Selected

    private func addSelectedSecurables() {
        for resultID in selectedResults {
            guard let item = searchResults.first(where: { $0.id == resultID }) else { continue }

            let alreadyExists = viewModel.securableEntries.contains {
                $0.securable.objectName == item.name && $0.securable.schemaName == item.schema
            }
            guard !alreadyExists else { continue }

            let classDesc: String
            switch item.typeName {
            case "Database": classDesc = "DATABASE"
            case "Schema": classDesc = "SCHEMA"
            default: classDesc = "OBJECT_OR_COLUMN"
            }

            let permissions = viewModel.applicablePermissions(for: classDesc)
            let ref = SecurableReference(
                typeName: item.typeName,
                schemaName: item.schema.isEmpty ? nil : item.schema,
                objectName: item.name,
                objectKind: item.objectKind
            )

            let entry = SecurableEntry(
                id: UUID(),
                securable: ref,
                permissions: permissions.map { perm in
                    PermissionGridRow(
                        permission: perm,
                        isGranted: false,
                        withGrantOption: false,
                        isDenied: false,
                        originalState: .none
                    )
                }
            )

            viewModel.securableEntries.append(entry)
        }
    }
}
