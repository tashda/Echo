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
                    .font(.system(size: 14, weight: .semibold))

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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
                    .font(.system(size: 14, weight: .semibold))

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
                                .font(.system(size: 11, weight: .semibold))
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(cardRowBackground(isNew: constraint.isNew))
    }

    internal var foreignKeysSection: some View {
        sectionCard(
            title: "Foreign Keys",
            subtitle: "Maintain relational integrity",
            systemImage: "link",
            action: SectionAction(title: "Add Foreign Key", systemImage: "plus", style: .accent) {
                presentNewForeignKey()
            }
        ) {
            if viewModel.foreignKeys.contains(where: { !$0.isDeleted }) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.foreignKeys.filter { !$0.isDeleted }) { model in
                        foreignKeyCard(model)
                    }
                }
            } else {
                placeholderText("No foreign keys defined")
            }
        }
    }

    private func presentNewForeignKey() {
        let model = viewModel.addForeignKey()
        activeForeignKeyEditor = ForeignKeyEditorPresentation(foreignKeyID: model.id, isNew: true)
    }

    private func presentForeignKeyEditor(for foreignKey: TableStructureEditorViewModel.ForeignKeyModel) {
        activeForeignKeyEditor = ForeignKeyEditorPresentation(foreignKeyID: foreignKey.id, isNew: foreignKey.isNew)
    }

    private func foreignKeyCard(_ foreignKey: TableStructureEditorViewModel.ForeignKeyModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(foreignKey.name)
                    .font(.system(size: 14, weight: .semibold))

                Spacer(minLength: 12)

                if foreignKey.isNew {
                    bubbleLabel("New", systemImage: "sparkles", tint: Color.accentColor.opacity(0.16), foreground: Color.accentColor)
                        .alignmentGuide(.firstTextBaseline) { dims in
                            dims[VerticalAlignment.center]
                        }
                } else {
                    Capsule()
                        .fill(foreignKey.isDirty ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.12))
                        .frame(width: 68, height: 22)
                        .overlay(
                            Text(foreignKey.isDirty ? "Modified" : "Synced")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(foreignKey.isDirty ? Color.accentColor : .secondary)
                        )
                        .alignmentGuide(.firstTextBaseline) { dims in
                            dims[VerticalAlignment.center]
                        }
                }

                Button {
                    presentForeignKeyEditor(for: foreignKey)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.borderless)

                Button(role: .destructive) {
                    viewModel.removeForeignKey(foreignKey)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove foreign key")
            }

            FlowLayout(alignment: .leading, spacing: 6) {
                let referenceTarget = "\(foreignKey.referencedSchema).\(foreignKey.referencedTable)"
                bubbleLabel(referenceTarget, systemImage: "building.columns")

                if foreignKey.columns.isEmpty {
                    bubbleLabel("No local columns", systemImage: "exclamationmark.triangle.fill", tint: Color.red.opacity(0.12), foreground: .red)
                } else {
                    bubbleLabel("Local", systemImage: "circle.grid.2x2", subtitle: foreignKey.columns.joined(separator: ", "))
                }

                if foreignKey.referencedColumns.isEmpty {
                    bubbleLabel("No reference columns", systemImage: "questionmark.circle", tint: Color.red.opacity(0.12), foreground: .red)
                } else {
                    bubbleLabel("References", systemImage: "arrowshape.turn.up.right", subtitle: foreignKey.referencedColumns.joined(separator: ", "))
                }

                if let onUpdate = foreignKey.onUpdate, !onUpdate.isEmpty {
                    bubbleLabel("ON UPDATE", systemImage: "arrow.triangle.2.circlepath", subtitle: onUpdate)
                }

                if let onDelete = foreignKey.onDelete, !onDelete.isEmpty {
                    bubbleLabel("ON DELETE", systemImage: "trash.circle", subtitle: onDelete)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(cardRowBackground(isNew: foreignKey.isNew))
    }

    internal var dependenciesSection: some View {
        sectionCard(
            title: "Dependencies",
            subtitle: "Other database objects referencing this table",
            systemImage: "rectangle.connected.to.line.below"
        ) {
            if viewModel.dependencies.isEmpty {
                placeholderText("No dependencies found")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.dependencies) { dependency in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dependency.name)
                                .font(.system(size: 13, weight: .semibold))

                            FlowLayout(alignment: .leading, spacing: 6) {
                                bubbleLabel("Table", systemImage: "tablecells", subtitle: dependency.referencedTable)
                                if dependency.baseColumns.isEmpty {
                                    bubbleLabel("No local columns", systemImage: "questionmark.circle", tint: Color.red.opacity(0.12), foreground: .red)
                                } else {
                                    bubbleLabel("Local", systemImage: "circle.grid.2x2", subtitle: dependency.baseColumns.joined(separator: ", "))
                                }
                                if dependency.referencedColumns.isEmpty {
                                    bubbleLabel("No reference columns", systemImage: "questionmark.circle", tint: Color.red.opacity(0.12), foreground: .red)
                                } else {
                                    bubbleLabel("References", systemImage: "arrowshape.turn.up.right", subtitle: dependency.referencedColumns.joined(separator: ", "))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(cardRowBackground(isNew: false))
                    }
                }
            }
        }
    }
}
