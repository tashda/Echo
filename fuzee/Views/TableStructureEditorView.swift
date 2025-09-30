import SwiftUI

struct TableStructureEditorView: View {
    @ObservedObject var tab: QueryTab
    @ObservedObject var viewModel: TableStructureEditorViewModel
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onDisappear {
            viewModel.lastError = nil
            viewModel.lastSuccessMessage = nil
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(tab.connection.connectionName) • \(viewModel.schemaName).\(viewModel.tableName)")
                    .font(.system(size: 16, weight: .semibold))
                Text("Structure editor")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Button("Reload") {
                Task { await viewModel.reload() }
            }
            .disabled(viewModel.isApplying)

            Button("Apply Changes") {
                Task {
                    await viewModel.applyChanges()
                    if viewModel.lastError == nil {
                        await appModel.refreshDatabaseStructure(for: tab.connectionSessionID, scope: .selectedDatabase, databaseOverride: tab.connection.database.isEmpty ? nil : tab.connection.database)
                    }
                }
            }
            .keyboardShortcut(.return, modifiers: [.command, .shift])
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasPendingChanges || viewModel.isApplying)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let message = viewModel.lastError {
                    statusMessage(text: message, systemImage: "exclamationmark.triangle.fill", tint: .red)
                } else if let success = viewModel.lastSuccessMessage {
                    statusMessage(text: success, systemImage: "checkmark.circle.fill", tint: .green)
                }

                columnsSection
                primaryKeySection
                indexesSection
                uniqueConstraintsSection
                foreignKeysSection
                dependenciesSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    private func statusMessage(text: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.1)))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 0.8)
        )
    }

    private var columnsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Columns", actionTitle: "Add new") {
                viewModel.addColumn()
            }

            LazyVStack(alignment: .leading, spacing: 6) {
                columnsHeaderRow
                ForEach(Array(viewModel.columns.enumerated()), id: \.element.id) { index, model in
                    if !model.isDeleted {
                        columnRow(binding: $viewModel.columns[index])
                    }
                }
            }
        }
    }

    private var columnsHeaderRow: some View {
        HStack {
            Text("Name").frame(width: 160, alignment: .leading)
            Text("Data Type").frame(width: 140, alignment: .leading)
            Text("Nullability").frame(width: 90, alignment: .leading)
            Text("Default Value").frame(width: 160, alignment: .leading)
            Text("Computed Expression").frame(width: 220, alignment: .leading)
            Spacer()
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
    }

    private func columnRow(binding: Binding<TableStructureEditorViewModel.ColumnModel>) -> some View {
        let column = binding.wrappedValue
        return HStack(alignment: .center, spacing: 12) {
            TextField("Column name", text: binding.name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)

            TextField("Data type", text: binding.dataType)
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)

            Toggle("", isOn: binding.isNullable)
                .toggleStyle(.switch)
                .labelsHidden()
                .frame(width: 90, alignment: .leading)

            TextField("Default", text: Binding(binding.defaultValue, replacingNilWith: ""))
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)

            TextField("Expression", text: Binding(binding.generatedExpression, replacingNilWith: ""))
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)

            Spacer()

            if !column.isNew {
                Text(column.isDirty ? "Modified" : "")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive) {
                viewModel.removeColumn(column)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(column.isNew ? 0.04 : 0.02)))
    }

    private var primaryKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Primary Key", actionTitle: primaryKeyActionTitle) {
                togglePrimaryKey()
            }

            if viewModel.primaryKey == nil {
                Text("No primary key defined")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(
                        "Constraint name",
                        text: Binding(
                            get: { viewModel.primaryKey?.name ?? "" },
                            set: { viewModel.primaryKey?.name = $0 }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)

                    columnMultiPicker(
                        title: "Columns",
                        selection: Binding(
                            get: { viewModel.primaryKey?.columns ?? [] },
                            set: { viewModel.primaryKey?.columns = $0 }
                        )
                    )
                }
                .padding(.horizontal, 12)
            }
        }
    }

    private var primaryKeyActionTitle: String {
        viewModel.primaryKey == nil ? "Add primary key" : "Remove"
    }

    private func togglePrimaryKey() {
        if viewModel.primaryKey == nil {
            viewModel.primaryKey = TableStructureEditorViewModel.PrimaryKeyModel(
                original: nil,
                name: "pk_\(viewModel.tableName)",
                columns: viewModel.columns.filter { !$0.isDeleted }.map { $0.name }
            )
            viewModel.clearPrimaryKeyRemoval()
        } else {
            viewModel.removePrimaryKey()
        }
    }

    private var indexesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Indexes", actionTitle: "Add index") {
                viewModel.addIndex()
            }

            if viewModel.indexes.contains(where: { !$0.isDeleted }) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(viewModel.indexes.enumerated()), id: \.element.id) { index, model in
                        if !model.isDeleted {
                            indexRow(binding: $viewModel.indexes[index])
                        }
                    }
                }
            } else {
                Text("No indexes")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }
        }
    }

    private func indexRow(binding: Binding<TableStructureEditorViewModel.IndexModel>) -> some View {
        let index = binding.wrappedValue
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Index name", text: binding.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)

                Toggle("Unique", isOn: binding.isUnique)
                Spacer()
                Button(role: .destructive) {
                    viewModel.removeIndex(index)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            columnMultiPicker(title: "Columns", selection: binding.columns)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(index.isNew ? 0.04 : 0.02)))
    }

    private var uniqueConstraintsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Unique Constraints", actionTitle: "Add new") {
                viewModel.addUniqueConstraint()
            }

            if viewModel.uniqueConstraints.contains(where: { !$0.isDeleted }) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(viewModel.uniqueConstraints.enumerated()), id: \.element.id) { index, model in
                        if !model.isDeleted {
                            uniqueConstraintRow(binding: $viewModel.uniqueConstraints[index])
                        }
                    }
                }
            } else {
                Text("No unique constraints defined")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }
        }
    }

    private func uniqueConstraintRow(binding: Binding<TableStructureEditorViewModel.UniqueConstraintModel>) -> some View {
        let constraint = binding.wrappedValue
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Constraint name", text: binding.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                Spacer()
                Button(role: .destructive) {
                    viewModel.removeUniqueConstraint(constraint)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            columnMultiPicker(title: "Columns", selection: binding.columns)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(constraint.isNew ? 0.04 : 0.02)))
    }

    private var foreignKeysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Foreign Keys", actionTitle: "Add new") {
                viewModel.addForeignKey()
            }

            if viewModel.foreignKeys.contains(where: { !$0.isDeleted }) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(viewModel.foreignKeys.enumerated()), id: \.element.id) { index, model in
                        if !model.isDeleted {
                            foreignKeyRow(binding: $viewModel.foreignKeys[index])
                        }
                    }
                }
            } else {
                Text("No foreign keys defined")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }
        }
    }

    private func foreignKeyRow(binding: Binding<TableStructureEditorViewModel.ForeignKeyModel>) -> some View {
        let fk = binding.wrappedValue
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Constraint name", text: binding.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)

                TextField("Referenced table", text: Binding(
                    get: { "\(binding.referencedSchema.wrappedValue).\(binding.referencedTable.wrappedValue)" },
                    set: { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let dot = trimmed.firstIndex(of: ".") {
                            binding.referencedSchema.wrappedValue = String(trimmed[..<dot])
                            binding.referencedTable.wrappedValue = String(trimmed[trimmed.index(after: dot)...])
                        } else {
                            binding.referencedTable.wrappedValue = trimmed
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)

                Spacer()
                Button(role: .destructive) {
                    viewModel.removeForeignKey(fk)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            columnMultiPicker(title: "Columns", selection: binding.columns)
            VStack(alignment: .leading, spacing: 4) {
                Text("Reference columns (comma separated)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField(
                    "team_id, venue_id",
                    text: Binding(
                        get: { binding.referencedColumns.wrappedValue.joined(separator: ", ") },
                        set: { newValue in
                            let components = newValue
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                            binding.referencedColumns.wrappedValue = components
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                TextField("ON UPDATE", text: Binding(binding.onUpdate, replacingNilWith: ""))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                TextField("ON DELETE", text: Binding(binding.onDelete, replacingNilWith: ""))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(fk.isNew ? 0.04 : 0.02)))
    }

    private var dependenciesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Dependencies", actionTitle: nil) {}
            if viewModel.dependencies.isEmpty {
                Text("No dependencies found")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.dependencies) { dependency in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dependency.name)
                                .font(.system(size: 12, weight: .semibold))
                            Text("Table: \(dependency.referencedTable)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text("Columns: \(dependency.baseColumns.joined(separator: ", ")) → \(dependency.referencedColumns.joined(separator: ", "))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.03)))
                    }
                }
            }
        }
    }

    private func sectionHeader(title: String, actionTitle: String?, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            if let actionTitle {
                Button(actionTitle, action: action)
            }
        }
    }

    private func columnMultiPicker(title: String, selection: Binding<[String]>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Menu {
                ForEach(viewModel.columns.filter { !$0.isDeleted }.map { $0.name }, id: \.self) { column in
                    let isSelected = selection.wrappedValue.contains(column)
                    Button(action: {
                        if isSelected {
                            selection.wrappedValue.removeAll { $0 == column }
                        } else {
                            selection.wrappedValue.append(column)
                        }
                    }) {
                        Label(column, systemImage: isSelected ? "checkmark" : "")
                    }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue.isEmpty ? "Select columns" : selection.wrappedValue.joined(separator: ", "))
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.04)))
            }
        }
    }
}

private extension Binding where Value == String? {
    init(_ source: Binding<String?>, replacingNilWith replacement: String) {
        self.init(get: {
            source.wrappedValue ?? replacement
        }, set: { newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            source.wrappedValue = trimmed.isEmpty ? nil : trimmed
        })
    }
}
