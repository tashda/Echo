import SwiftUI

extension TableStructureEditorView {
    
    internal var indexesSection: some View {
        sectionCard(
            title: "Indexes",
            subtitle: "Optimize filtered reads",
            systemImage: "rectangle.3.group.bubble.left",
            action: SectionAction(title: "Add index", systemImage: "plus", style: .accent) {
                let newIndex = viewModel.addIndex()
                activeIndexEditor = IndexEditorPresentation(indexID: newIndex.id)
            }
        ) {
            if viewModel.indexes.contains(where: { !$0.isDeleted }) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.indexes.filter { !$0.isDeleted }) { model in
                        indexCard(model)
                    }
                }
            } else {
                placeholderText("No indexes defined")
            }
        }
    }

    private func indexCard(_ index: TableStructureEditorViewModel.IndexModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(index.name)
                    .font(.system(size: 14, weight: .semibold))
                countBadge(for: index)
                if index.isUnique {
                    uniqueBadge
                }

                Spacer(minLength: 12)

                if !index.isNew {
                    Capsule()
                        .fill(index.isDirty ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.12))
                        .frame(width: 68, height: 22)
                        .overlay(
                            Text(index.isDirty ? "Modified" : "Synced")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(index.isDirty ? Color.accentColor : .secondary)
                        )
                }

                Button {
                    activeIndexEditor = IndexEditorPresentation(indexID: index.id)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.borderless)
                .help("Edit index")

                Button(role: .destructive) {
                    viewModel.removeIndex(index)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove index")
            }

            if let filter = index.effectiveFilterCondition, !filter.isEmpty {
                bubbleLabel("Filter", systemImage: "line.3.horizontal.decrease.circle", subtitle: filter)
            }

            if index.columns.isEmpty {
                bubbleLabel("No columns assigned", systemImage: "exclamationmark.triangle.fill", tint: Color.red.opacity(0.12), foreground: .red)
            } else {
                columnChips(for: index)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(cardRowBackground(isNew: index.isNew))
    }

    private var uniqueBadge: some View {
        Text("unique")
            .font(.system(size: 9, weight: .semibold))
            .textCase(.lowercase)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.16))
            )
            .alignmentGuide(.firstTextBaseline) { dimensions in
                dimensions[VerticalAlignment.center]
            }
    }

    private func columnChips(for index: TableStructureEditorViewModel.IndexModel) -> some View {
        FlowLayout(alignment: .leading, spacing: 6) {
            ForEach(index.columns, id: \.id) { column in
                HStack(spacing: 4) {
                    Text(column.name)
                        .font(.system(size: 10, weight: .semibold))
                    Text(column.sortOrder == .ascending ? "ASC" : "DESC")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color(nsColor: .unemphasizedSelectedTextBackgroundColor))
                )
                .overlay(
                    Capsule()
                        .stroke(Color(nsColor: .separatorColor).opacity(0.18))
                )
                .fixedSize()
            }
        }
    }

    private func countBadge(for index: TableStructureEditorViewModel.IndexModel) -> some View {
        Text("\(index.columns.count)")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.08), in: Capsule())
            .alignmentGuide(.firstTextBaseline) { dimensions in
                dimensions[VerticalAlignment.center]
            }
    }
}
