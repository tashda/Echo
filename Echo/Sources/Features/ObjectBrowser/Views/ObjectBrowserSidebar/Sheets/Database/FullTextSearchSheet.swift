import SwiftUI
import SQLServerKit

/// Read-only panel showing full-text catalogs and indexes in the current database.
struct FullTextSearchSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let onDismiss: () -> Void

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var catalogs: [SQLServerFullTextCatalog] = []
    @State private var indexes: [SQLServerFullTextIndex] = []
    @State private var showNewCatalogSheet = false
    @State private var confirmDropCatalog: SQLServerFullTextCatalog?
    @State private var isBusy = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else {
                contentView
            }

            Divider()

            footerBar
        }
        .frame(minWidth: 480, minHeight: 340)
        .frame(idealWidth: 520, idealHeight: 380)
        .task { await loadData() }
        .sheet(isPresented: $showNewCatalogSheet) {
            NewFullTextCatalogSheet { name, isDefault, accentSensitive in
                await createCatalog(name: name, isDefault: isDefault, accentSensitive: accentSensitive)
            } onCancel: {
                showNewCatalogSheet = false
            }
        }
        .alert("Drop Catalog?", isPresented: Binding(
            get: { confirmDropCatalog != nil },
            set: { if !$0 { confirmDropCatalog = nil } }
        )) {
            Button("Cancel", role: .cancel) { confirmDropCatalog = nil }
            Button("Drop", role: .destructive) {
                if let catalog = confirmDropCatalog {
                    confirmDropCatalog = nil
                    Task { await dropCatalog(name: catalog.name) }
                }
            }
        } message: {
            Text("Are you sure you want to drop the catalog \(confirmDropCatalog?.name ?? "")? This action cannot be undone.")
        }
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "text.magnifyingglass")
                .foregroundStyle(ColorTokens.accent)
            Text("Full-Text Search")
                .font(TypographyTokens.prominent.weight(.semibold))
            Spacer()
            Text(databaseName)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(SpacingTokens.md)
    }

    private var footerBar: some View {
        HStack {
            Spacer()
            Button("Done") { onDismiss() }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
        }
        .padding(SpacingTokens.md)
    }

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                catalogsSection
                indexesSection
            }
            .padding(SpacingTokens.md)
        }
    }

    @ViewBuilder
    private var catalogsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Text("Full-Text Catalogs")
                    .font(TypographyTokens.standard.weight(.semibold))
                Spacer()
                Button {
                    showNewCatalogSheet = true
                } label: {
                    Label("New Catalog", systemImage: "books.vertical")
                }
                .controlSize(.small)
                .disabled(isBusy)
            }

            if catalogs.isEmpty {
                Text("No full-text catalogs in this database.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                ForEach(catalogs) { catalog in
                    HStack(spacing: SpacingTokens.sm) {
                        Image(systemName: "books.vertical")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                        Text(catalog.name)
                            .font(TypographyTokens.standard)
                        Spacer()
                        if catalog.isDefault {
                            Text("Default")
                                .font(TypographyTokens.compact)
                                .foregroundStyle(ColorTokens.accent)
                        }
                        Text(catalog.isAccentSensitive ? "Accent-sensitive" : "Accent-insensitive")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    .padding(SpacingTokens.xs)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ColorTokens.Background.secondary)
                    )
                    .contextMenu {
                        Button {
                            Task { await rebuildCatalog(name: catalog.name) }
                        } label: {
                            Label("Rebuild", systemImage: "hammer")
                        }
                        .disabled(isBusy)

                        Divider()

                        Button(role: .destructive) {
                            confirmDropCatalog = catalog
                        } label: {
                            Label("Drop Catalog", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var indexesSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Full-Text Indexes")
                .font(TypographyTokens.standard.weight(.semibold))

            if indexes.isEmpty {
                Text("No full-text indexes in this database.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                ForEach(indexes) { index in
                    HStack(spacing: SpacingTokens.sm) {
                        Image(systemName: "tablecells")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                        Text(index.tableName)
                            .font(TypographyTokens.standard)
                        Spacer()
                        Circle()
                            .fill(index.isEnabled ? ColorTokens.Status.success : ColorTokens.Text.quaternary)
                            .frame(width: 8, height: 8)
                        Text(index.isEnabled ? "Enabled" : "Disabled")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                    .padding(SpacingTokens.xs)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ColorTokens.Background.secondary)
                    )
                    .contextMenu {
                        Button {
                            Task { await startPopulation(table: index.tableName, type: .full) }
                        } label: {
                            Label("Start Full Population", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(isBusy)

                        Button {
                            Task { await startPopulation(table: index.tableName, type: .incremental) }
                        } label: {
                            Label("Start Incremental Population", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(isBusy)

                        Button {
                            Task { await stopPopulation(table: index.tableName) }
                        } label: {
                            Label("Stop Population", systemImage: "stop.circle")
                        }
                        .disabled(isBusy)

                        Divider()

                        Button(role: .destructive) {
                            Task { await dropIndex(table: index.tableName) }
                        } label: {
                            Label("Drop Index", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading full-text search\u{2026}")
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack {
            Spacer()
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(ColorTokens.Text.secondary)
            Spacer()
        }
        .padding()
    }

    private func loadData() async {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not a SQL Server connection."
            isLoading = false
            return
        }

        do {
            catalogs = try await mssql.fullText.listCatalogs()
            indexes = try await mssql.fullText.listIndexes()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func createCatalog(name: String, isDefault: Bool, accentSensitive: Bool) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isBusy = true
        do {
            try await mssql.fullText.createCatalog(name: name, isDefault: isDefault, accentSensitive: accentSensitive)
            showNewCatalogSheet = false
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }

    private func dropCatalog(name: String) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isBusy = true
        do {
            try await mssql.fullText.dropCatalog(name: name)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }

    private func rebuildCatalog(name: String) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isBusy = true
        do {
            try await mssql.fullText.rebuildCatalog(name: name)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }

    private func dropIndex(table: String) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isBusy = true
        do {
            try await mssql.fullText.dropIndex(schema: "dbo", table: table)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }

    private func startPopulation(table: String, type: SQLServerFullTextClient.PopulationType) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isBusy = true
        do {
            try await mssql.fullText.startPopulation(schema: "dbo", table: table, type: type)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }

    private func stopPopulation(table: String) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isBusy = true
        do {
            try await mssql.fullText.stopPopulation(schema: "dbo", table: table)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }
}
