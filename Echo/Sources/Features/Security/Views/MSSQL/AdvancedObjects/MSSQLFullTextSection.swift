import SwiftUI
import SQLServerKit

struct MSSQLFullTextSection: View {
    @Bindable var viewModel: MSSQLAdvancedObjectsViewModel
    @Binding var showNewCatalogSheet: Bool
    @Binding var showNewIndexSheet: Bool

    @State private var confirmDropCatalog: SQLServerFullTextCatalog?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                catalogsSection
                indexesSection
            }
            .padding(SpacingTokens.md)
        }
        .alert("Drop Catalog?", isPresented: Binding(
            get: { confirmDropCatalog != nil },
            set: { if !$0 { confirmDropCatalog = nil } }
        )) {
            Button("Cancel", role: .cancel) { confirmDropCatalog = nil }
            Button("Drop", role: .destructive) {
                if let catalog = confirmDropCatalog {
                    confirmDropCatalog = nil
                    Task { await viewModel.dropCatalog(name: catalog.name) }
                }
            }
        } message: {
            Text("Are you sure you want to drop the catalog \(confirmDropCatalog?.name ?? "")? This action cannot be undone.")
        }
    }

    @ViewBuilder
    private var catalogsSection: some View {
        GroupBox {
            if viewModel.ftCatalogs.isEmpty {
                HStack {
                    Text("No full-text catalogs in this database.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Spacer()
                    Button { showNewCatalogSheet = true } label: {
                        Label("New Catalog", systemImage: "plus")
                    }
                    .controlSize(.small)
                    .disabled(viewModel.isBusy)
                }
                .padding(.vertical, SpacingTokens.sm)
            } else {
                VStack(spacing: SpacingTokens.xxs) {
                    ForEach(viewModel.ftCatalogs) { catalog in
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
                                Task { await viewModel.rebuildCatalog(name: catalog.name) }
                            } label: {
                                Label("Rebuild", systemImage: "hammer")
                            }
                            .disabled(viewModel.isBusy)

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
        } label: {
            Text("Full-Text Catalogs")
                .font(TypographyTokens.standard.weight(.semibold))
        }
    }

    @ViewBuilder
    private var indexesSection: some View {
        GroupBox {
            if viewModel.ftIndexes.isEmpty {
                HStack {
                    Text("No full-text indexes in this database.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Spacer()
                    Button { showNewIndexSheet = true } label: {
                        Label("New Index", systemImage: "plus")
                    }
                    .controlSize(.small)
                    .disabled(viewModel.isBusy || viewModel.ftCatalogs.isEmpty)
                }
                .padding(.vertical, SpacingTokens.sm)
            } else {
                VStack(spacing: SpacingTokens.xxs) {
                    ForEach(viewModel.ftIndexes) { index in
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
                                Task { await viewModel.startPopulation(schema: "dbo", table: index.tableName, type: .full) }
                            } label: {
                                Label("Start Full Population", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .disabled(viewModel.isBusy)

                            Button {
                                Task { await viewModel.startPopulation(schema: "dbo", table: index.tableName, type: .incremental) }
                            } label: {
                                Label("Start Incremental Population", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .disabled(viewModel.isBusy)

                            Button {
                                Task { await viewModel.stopPopulation(schema: "dbo", table: index.tableName) }
                            } label: {
                                Label("Stop Population", systemImage: "stop.circle")
                            }
                            .disabled(viewModel.isBusy)

                            Divider()

                            Button(role: .destructive) {
                                Task { await viewModel.dropFullTextIndex(schema: "dbo", table: index.tableName) }
                            } label: {
                                Label("Drop Index", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("Full-Text Indexes")
                    .font(TypographyTokens.standard.weight(.semibold))
                Spacer()
                if !viewModel.ftIndexes.isEmpty {
                    Button { showNewIndexSheet = true } label: {
                        Label("New Index", systemImage: "plus")
                    }
                    .controlSize(.small)
                    .disabled(viewModel.isBusy || viewModel.ftCatalogs.isEmpty)
                }
            }
        }
    }
}
