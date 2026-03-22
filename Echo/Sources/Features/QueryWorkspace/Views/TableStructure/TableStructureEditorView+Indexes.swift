import SwiftUI

extension TableStructureEditorView {

    internal var indexesContent: some View {
        Group {
            if activeIndexes.isEmpty {
                ContentUnavailableView {
                    Label("No Indexes", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Indexes improve query performance on frequently searched columns.")
                } actions: {
                    Button("Add Index") {
                        let newIndex = viewModel.addIndex()
                        activeIndexEditor = IndexEditorPresentation(indexID: newIndex.id)
                    }
                }
            } else {
                indexesTable
            }
        }
    }

    private var activeIndexes: [TableStructureEditorViewModel.IndexModel] {
        viewModel.indexes.filter { !$0.isDeleted }
    }

    private var indexesTable: some View {
        Table(of: TableStructureEditorViewModel.IndexModel.self, selection: $selectedIndexIDs) {
            TableColumn("Kind") { index in
                Text(index.isUnique ? "UQ" : "IX")
                    .font(TypographyTokens.Table.kindBadge)
                    .foregroundStyle(index.isUnique ? .blue : ColorTokens.Text.tertiary)
            }
            .width(35)

            TableColumn("Name") { index in
                Text(index.name)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 120, ideal: 200)

            TableColumn("Type") { index in
                Text(indexTypeDisplay(index))
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(viewModel.databaseType == .microsoftSQL ? 100 : 60)

            TableColumn("Key Columns") { index in
                Text(indexKeyColumns(index))
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .help(indexKeyColumns(index))
            }
            .width(min: 100, ideal: 200)

            TableColumn("Include") { index in
                let included = indexIncludeColumns(index)
                Text(included.isEmpty ? "\u{2014}" : included)
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(included.isEmpty ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
                    .help(included)
            }
            .width(min: 60, ideal: 120)

            TableColumn("Filter") { index in
                Text(index.effectiveFilterCondition ?? "\u{2014}")
                    .font(TypographyTokens.Table.sql)
                    .foregroundStyle(index.effectiveFilterCondition != nil ? ColorTokens.Text.secondary : ColorTokens.Text.tertiary)
                    .help(index.effectiveFilterCondition ?? "")
            }
            .width(min: 60, ideal: 120)
        } rows: {
            ForEach(activeIndexes) { index in
                TableRow(index)
            }
        }
        .contextMenu(forSelectionType: TableStructureEditorViewModel.IndexModel.ID.self) { selection in
            if selection.isEmpty {
                Button("Add Index") {
                    let newIndex = viewModel.addIndex()
                    activeIndexEditor = IndexEditorPresentation(indexID: newIndex.id)
                }
            } else if let indexID = selection.first,
               let index = activeIndexes.first(where: { $0.id == indexID }) {
                Button("Edit Index") {
                    activeIndexEditor = IndexEditorPresentation(indexID: index.id)
                }

                if !index.isNew {
                    Button("Rebuild Index") {
                        Task { await rebuildIndex(index) }
                    }
                }

                Divider()

                Button("Delete Index", role: .destructive) {
                    viewModel.removeIndex(index)
                }
            }
        } primaryAction: { selection in
            if let indexID = selection.first {
                activeIndexEditor = IndexEditorPresentation(indexID: indexID)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .environment(\.defaultMinListRowHeight, 28)
    }

    private func rebuildIndex(_ index: TableStructureEditorViewModel.IndexModel) async {
        environmentState.notificationEngine?.post(category: .generalInfo, icon: "arrow.triangle.2.circlepath", message: "Rebuilding index \"\(index.name)\"", style: .info)
        await viewModel.rebuildIndex(index)
        if let error = viewModel.lastError {
            environmentState.notificationEngine?.post(category: .indexRebuildFailed, message: error)
        } else {
            environmentState.notificationEngine?.post(category: .indexRebuilt, message: "Index \"\(index.name)\" rebuilt successfully")
        }
    }

    private func indexTypeDisplay(_ index: TableStructureEditorViewModel.IndexModel) -> String {
        if viewModel.databaseType == .microsoftSQL {
            // MSSQL: "clustered", "nonclustered", etc.
            return index.indexType.lowercased()
        } else {
            // PG: "btree", "gin", "gist", "brin", "hash"
            return index.indexType.lowercased()
        }
    }

    private func indexKeyColumns(_ index: TableStructureEditorViewModel.IndexModel) -> String {
        index.columns.filter { !$0.isIncluded }.map { col in
            col.sortOrder == .descending ? "\(col.name) DESC" : col.name
        }.joined(separator: ", ")
    }

    private func indexIncludeColumns(_ index: TableStructureEditorViewModel.IndexModel) -> String {
        index.columns.filter { $0.isIncluded }.map(\.name).joined(separator: ", ")
    }
}
