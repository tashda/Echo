import SwiftUI

extension TableStructureEditorView {

    internal var constraintsPanel: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sm) {
            primaryKeyCard
            uniqueConstraintsCard
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.vertical, SpacingTokens.sm)
    }

    // MARK: - Primary Key Card

    private var primaryKeyCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xxs) {
                Image(systemName: "key.fill")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(accentColor)
                Text("Primary Key")
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.primary)
            }

            if let pk = viewModel.primaryKey {
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    HStack(spacing: SpacingTokens.xxs) {
                        if pk.isNew || pk.isDirty {
                            Circle()
                                .fill(accentColor)
                                .frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
                        }
                        Text(pk.name)
                            .font(TypographyTokens.standard.weight(.medium))
                            .lineLimit(1)
                    }
                    Text(pk.columns.joined(separator: ", "))
                        .font(TypographyTokens.detail.monospaced())
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Edit Primary Key\u{2026}") {
                        presentPrimaryKeyEditor(isNew: false)
                    }
                    Divider()
                    Button("Delete Primary Key", role: .destructive) {
                        viewModel.removePrimaryKey()
                    }
                }
                .onTapGesture(count: 2) {
                    presentPrimaryKeyEditor(isNew: false)
                }
            } else {
                Button {
                    presentPrimaryKeyEditor(isNew: true)
                } label: {
                    Label("Add Primary Key", systemImage: "plus")
                        .font(TypographyTokens.detail)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous)
                .fill(ColorTokens.Text.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous)
                .stroke(ColorTokens.Text.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Unique Constraints Card

    private var uniqueConstraintsCard: some View {
        let active = activeUniqueConstraints

        return VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xxs) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(accentColor)
                Text("Unique Constraints")
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.primary)

                if !active.isEmpty {
                    Text("\(active.count)")
                        .font(TypographyTokens.label.weight(.medium))
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .padding(.horizontal, SpacingTokens.xxs2)
                        .background(ColorTokens.Text.primary.opacity(0.06), in: Capsule())
                }

                Spacer()

                Button {
                    presentNewUniqueConstraint()
                } label: {
                    Image(systemName: "plus")
                        .font(TypographyTokens.detail)
                }
                .buttonStyle(.borderless)
            }

            if active.isEmpty {
                Text("None defined")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    ForEach(active) { constraint in
                        HStack(spacing: SpacingTokens.xxs) {
                            if constraint.isNew || constraint.isDirty {
                                Circle()
                                    .fill(accentColor)
                                    .frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
                            }
                            Text(constraint.name)
                                .font(TypographyTokens.standard.weight(.medium))
                                .lineLimit(1)
                            Text(constraint.columns.joined(separator: ", "))
                                .font(TypographyTokens.detail.monospaced())
                                .foregroundStyle(ColorTokens.Text.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Edit Constraint\u{2026}") {
                                presentUniqueConstraintEditor(for: constraint)
                            }
                            Divider()
                            Button("Delete Constraint", role: .destructive) {
                                viewModel.removeUniqueConstraint(constraint)
                            }
                        }
                        .onTapGesture(count: 2) {
                            presentUniqueConstraintEditor(for: constraint)
                        }
                    }
                }
            }
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous)
                .fill(ColorTokens.Text.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous)
                .stroke(ColorTokens.Text.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var activeUniqueConstraints: [TableStructureEditorViewModel.UniqueConstraintModel] {
        viewModel.uniqueConstraints.filter { !$0.isDeleted }
    }

    // MARK: - Presentation

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

    private func presentNewUniqueConstraint() {
        let model = viewModel.addUniqueConstraint()
        activeUniqueConstraintEditor = UniqueConstraintEditorPresentation(constraintID: model.id, isNew: true)
    }

    private func presentUniqueConstraintEditor(for constraint: TableStructureEditorViewModel.UniqueConstraintModel) {
        activeUniqueConstraintEditor = UniqueConstraintEditorPresentation(constraintID: constraint.id, isNew: constraint.isNew)
    }
}
