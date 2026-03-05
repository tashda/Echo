import SwiftUI

extension TableStructureEditorView {
    
    internal var primaryKeySection: some View {
        sectionCard(
            title: "Primary Key",
            subtitle: "Ensure row uniqueness",
            systemImage: "key",
            action: primaryKeySectionAction
        ) {
            if let primaryKey = viewModel.primaryKey {
                primaryKeyCard(primaryKey)
            } else {
                placeholderText("No primary key")
            }
        }
    }

    private var primaryKeySectionAction: SectionAction? {
        if viewModel.primaryKey == nil {
            return SectionAction(title: "Add Primary Key", systemImage: "plus", style: .accent) {
                presentPrimaryKeyEditor(isNew: true)
            }
        } else {
            return SectionAction(title: "Remove", systemImage: "trash") {
                viewModel.removePrimaryKey()
            }
        }
    }

    private func presentPrimaryKeyEditor(isNew: Bool) {
        if isNew {
            viewModel.primaryKey = TableStructureEditorViewModel.PrimaryKeyModel(
                original: nil,
                name: "pk_\(viewModel.tableName)",
                columns: viewModel.columns.filter { !$0.isDeleted }.map { $0.name }
            )
            viewModel.clearPrimaryKeyRemoval()
        }

        guard viewModel.primaryKey != nil else { return }
        activePrimaryKeyEditor = PrimaryKeyEditorPresentation(isNew: isNew)
    }

    private func primaryKeyCard(_ primaryKey: TableStructureEditorViewModel.PrimaryKeyModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(primaryKey.name)
                    .font(TypographyTokens.prominent.weight(.semibold))

                Spacer(minLength: 12)

                bubbleLabel("Columns: \(primaryKey.columns.count)", systemImage: "number", tint: Color.accentColor.opacity(0.1), foreground: Color.accentColor)
                    .alignmentGuide(.firstTextBaseline) { dims in
                        dims[VerticalAlignment.center]
                    }

                Button {
                    presentPrimaryKeyEditor(isNew: false)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.borderless)
                .help("Edit primary key")
            }

            FlowLayout(alignment: .leading, spacing: 6) {
                ForEach(primaryKey.columns, id: \.self) { column in
                    bubbleLabel(column, systemImage: "circle.fill")
                }
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
        .background(cardRowBackground(isNew: false))
    }

    internal var uniqueConstraintsSection: some View {
        sectionCard(
            title: "Unique Constraints",
            subtitle: "Prevent duplicate values",
            systemImage: "shield.lefthalf.filled",
            action: SectionAction(title: "Add Constraint", systemImage: "plus", style: .accent) {
                presentNewUniqueConstraint()
            }
        ) {
            if viewModel.uniqueConstraints.contains(where: { !$0.isDeleted }) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.uniqueConstraints.filter { !$0.isDeleted }) { model in
                        uniqueConstraintCard(model)
                    }
                }
            } else {
                placeholderText("No unique constraints")
            }
        }
    }

    private func presentNewUniqueConstraint() {
        let model = viewModel.addUniqueConstraint()
        activeUniqueConstraintEditor = UniqueConstraintEditorPresentation(constraintID: model.id, isNew: true)
    }

    private func presentUniqueConstraintEditor(for constraint: TableStructureEditorViewModel.UniqueConstraintModel) {
        activeUniqueConstraintEditor = UniqueConstraintEditorPresentation(constraintID: constraint.id, isNew: constraint.isNew)
    }

    private func uniqueConstraintCard(_ constraint: TableStructureEditorViewModel.UniqueConstraintModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(constraint.name)
                    .font(TypographyTokens.prominent.weight(.semibold))

                Spacer(minLength: 12)

                if constraint.isNew {
                    bubbleLabel("New", systemImage: "sparkles", tint: Color.accentColor.opacity(0.16), foreground: Color.accentColor)
                        .alignmentGuide(.firstTextBaseline) { dims in
                            dims[VerticalAlignment.center]
                        }
                } else {
                    Capsule()
                        .fill(constraint.isDirty ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.12))
                        .frame(width: 68, height: 22)
                        .overlay(
                            Text(constraint.isDirty ? "Modified" : "Synced")
                                .font(TypographyTokens.detail.weight(.semibold))
                                .foregroundStyle(constraint.isDirty ? Color.accentColor : .secondary)
                        )
                        .alignmentGuide(.firstTextBaseline) { dims in
                            dims[VerticalAlignment.center]
                        }
                }

                Button {
                    presentUniqueConstraintEditor(for: constraint)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.borderless)

                Button(role: .destructive) {
                    viewModel.removeUniqueConstraint(constraint)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove constraint")
            }

            if constraint.columns.isEmpty {
                bubbleLabel("No columns assigned", systemImage: "exclamationmark.triangle.fill", tint: Color.red.opacity(0.12), foreground: .red)
            } else {
                FlowLayout(alignment: .leading, spacing: 6) {
                    ForEach(constraint.columns, id: \.self) { column in
                        bubbleLabel(column, systemImage: "circle.fill")
                    }
                }
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
        .background(cardRowBackground(isNew: constraint.isNew))
    }

}
