import SwiftUI

extension TableStructureEditorView {

    internal var indexesContent: some View {
        VStack(spacing: 0) {
            sectionToolbar(title: "Indexes", count: activeIndexes.count) {
                let newIndex = viewModel.addIndex()
                activeIndexEditor = IndexEditorPresentation(indexID: newIndex.id)
            }

            Divider()

            if activeIndexes.isEmpty {
                EmptyStatePlaceholder(
                    icon: "list.bullet.rectangle",
                    title: "No Indexes",
                    subtitle: "Indexes improve query performance on frequently searched columns.",
                    actionTitle: "Add Index"
                ) {
                    let newIndex = viewModel.addIndex()
                    activeIndexEditor = IndexEditorPresentation(indexID: newIndex.id)
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
            TableColumn("Name") { index in
                HStack(spacing: SpacingTokens.xxs) {
                    if index.isNew || index.isDirty {
                        Circle()
                            .fill(accentColor)
                            .frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
                    }
                    Text(index.name)
                        .font(TypographyTokens.standard.weight(.medium))
                }
            }
            .width(min: 120, ideal: 200)

            TableColumn("Unique") { index in
                Image(systemName: index.isUnique ? "checkmark" : "minus")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(index.isUnique ? accentColor : ColorTokens.Text.tertiary)
            }
            .width(55)

            TableColumn("Columns") { index in
                Text(indexColumnsDescription(index))
                    .font(TypographyTokens.detail.monospaced())
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .help(indexColumnsDescription(index))
            }
            .width(min: 120, ideal: 260)

            TableColumn("Filter") { index in
                Text(index.effectiveFilterCondition ?? "\u{2014}")
                    .font(TypographyTokens.detail.monospaced())
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
            if let indexID = selection.first,
               let index = activeIndexes.first(where: { $0.id == indexID }) {
                Button("Edit Index\u{2026}") {
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
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
        .environment(\.defaultMinListRowHeight, 28)
    }

    private func rebuildIndex(_ index: TableStructureEditorViewModel.IndexModel) async {
        environmentState.notificationEngine?.post(category: .generalInfo, icon: "arrow.triangle.2.circlepath", message: "Rebuilding index \"\(index.name)\"\u{2026}", style: .info)
        await viewModel.rebuildIndex(index)
        if let error = viewModel.lastError {
            environmentState.notificationEngine?.post(category: .indexRebuildFailed, message: error)
        } else {
            environmentState.notificationEngine?.post(category: .indexRebuilt, message: "Index \"\(index.name)\" rebuilt successfully")
        }
    }

    private func indexColumnsDescription(_ index: TableStructureEditorViewModel.IndexModel) -> String {
        index.columns.map { col in
            col.sortOrder == .descending ? "\(col.name) DESC" : col.name
        }.joined(separator: ", ")
    }
}
