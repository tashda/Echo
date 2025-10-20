import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#endif

// MARK: - Column Editor Sheet

struct ColumnEditorSheet: View {
    @Binding var column: TableStructureEditorViewModel.ColumnModel
    let databaseType: DatabaseType
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var draft: Draft

    init(
        column: Binding<TableStructureEditorViewModel.ColumnModel>,
        databaseType: DatabaseType,
        onDelete: @escaping () -> Void,
        onCancelNew: @escaping () -> Void
    ) {
        self._column = column
        self.databaseType = databaseType
        self.onDelete = onDelete
        self.onCancelNew = onCancelNew
        _draft = State(initialValue: Draft(model: column.wrappedValue, databaseType: databaseType))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                generalSection
                behaviorSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            toolbar
        }
        .frame(minWidth: 440, idealWidth: 500, minHeight: 360)
        .navigationTitle(draft.isEditingExisting ? "Edit Column" : "New Column")
    }

    private var generalSection: some View {
        Section {
            labeledRow(title: "Column Name") {
                TextField("", text: $draft.name)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if isPostgres {
                labeledRow(title: "Data Type") {
                    Picker("", selection: postgresTypeSelectionBinding) {
                        Text("Custom").tag("")
                        ForEach(postgresDataTypeOptions, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 180, alignment: .trailing)
                }
                if draft.selectedDataType == nil {
                    labeledRow(title: "Custom Data Type") {
                        TextField("", text: dataTypeInputBinding)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            } else {
                labeledRow(title: "Data Type") {
                    TextField("", text: dataTypeInputBinding)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        } footer: {
            if !draft.canSave {
                Text("Name and data type cannot be empty.")
                    .foregroundStyle(.red)
            }
        }
    }

    private var behaviorSection: some View {
        Section {
            Toggle("Allow NULL values", isOn: $draft.isNullable)
            labeledRow(title: "Default Value") {
                TextField("", text: $draft.defaultValue)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Generated Expression")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $draft.generatedExpression)
                    .font(.system(size: 13))
                    .frame(minHeight: generatedExpressionHeight, maxHeight: generatedExpressionHeight)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(fieldBackgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(fieldStrokeColor, lineWidth: 1)
                    )
            }
        } header: {
            Text("Behavior")
        } footer: {
            Text("Leave optional fields blank to omit them.")
        }
    }

    private func labeledRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .frame(minWidth: 120, alignment: .leading)
            Spacer(minLength: 0)
            content()
        }
        .frame(maxWidth: .infinity)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if draft.isEditingExisting {
                Button("Delete Column", role: .destructive) {
                    dismiss()
                    onDelete()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            Spacer()

            Button("Cancel") {
                cancelEditing()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                applyDraft()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!draft.canSave)
            .keyboardShortcut(.defaultAction)
            .tint(themeManager.accentColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(toolbarBackgroundColor)
        .overlay(
            Rectangle()
                .fill(toolbarBorderColor)
                .frame(height: 1),
            alignment: .top
        )
    }

    private func applyDraft() {
        column.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        column.dataType = draft.dataType.trimmingCharacters(in: .whitespacesAndNewlines)
        column.isNullable = draft.isNullable

        let defaultTrimmed = draft.defaultValue.trimmingCharacters(in: .whitespacesAndNewlines)
        column.defaultValue = defaultTrimmed.isEmpty ? nil : defaultTrimmed

        let expressionTrimmed = draft.generatedExpression.trimmingCharacters(in: .whitespacesAndNewlines)
        column.generatedExpression = expressionTrimmed.isEmpty ? nil : expressionTrimmed

        dismiss()
    }

    private func cancelEditing() {
        dismiss()
        if !draft.isEditingExisting {
            onCancelNew()
        }
    }

    private var isPostgres: Bool { databaseType == .postgresql }

    private var sheetBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: themeManager.windowBackgroundNSColor)
        #else
        themeManager.windowBackgroundColor
        #endif
    }

    private var fieldBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: themeManager.surfaceBackgroundNSColor).opacity(0.9)
        #else
        themeManager.surfaceBackgroundColor.opacity(0.9)
        #endif
    }

    private var fieldStrokeColor: Color {
        let foreground = themeManager.surfaceForegroundColor
        return foreground.opacity(themeManager.effectiveColorScheme == .dark ? 0.18 : 0.25)
    }

    private var toolbarBackgroundColor: Color {
#if os(macOS)
        Color(nsColor: themeManager.surfaceBackgroundNSColor)
#else
        themeManager.surfaceBackgroundColor
#endif
    }

    private var toolbarBorderColor: Color {
        themeManager.surfaceForegroundColor.opacity(themeManager.effectiveColorScheme == .dark ? 0.3 : 0.12)
    }

    private var sheetCornerRadius: CGFloat { 18 }

    private var sheetShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: sheetCornerRadius, style: .continuous)
    }

    private var sheetBorderColor: Color {
        let foreground = themeManager.surfaceForegroundColor
        return foreground.opacity(themeManager.effectiveColorScheme == .dark ? 0.2 : 0.08)
    }

    private var sheetShadowColor: Color {
        themeManager.effectiveColorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.16)
    }

    private var generatedExpressionHeight: CGFloat {
        CGFloat(88) // approximate four lines of text
    }

    private var postgresTypeSelectionBinding: Binding<String> {
        Binding<String>(
            get: { draft.selectedDataType ?? "" },
            set: { newValue in
                draft.selectedDataType = newValue.isEmpty ? nil : newValue
                if !newValue.isEmpty {
                    draft.dataType = newValue
                }
            }
        )
    }

    private var dataTypeInputBinding: Binding<String> {
        Binding(
            get: { draft.dataType },
            set: { newValue in
                draft.dataType = newValue
                updateSelectedPreset(for: newValue)
            }
        )
    }

    private func updateSelectedPreset(for value: String) {
        guard isPostgres else { return }
        if let match = postgresDataTypeOptions.first(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
            draft.selectedDataType = match
        } else {
            draft.selectedDataType = nil
        }
    }

    private struct Draft {
        var name: String
        var dataType: String
        var isNullable: Bool
        var defaultValue: String
        var generatedExpression: String
        let isEditingExisting: Bool
        var selectedDataType: String?

        init(model: TableStructureEditorViewModel.ColumnModel, databaseType: DatabaseType) {
            self.name = model.name
            self.dataType = model.dataType
            self.isNullable = model.isNullable
            self.defaultValue = model.defaultValue ?? ""
            self.generatedExpression = model.generatedExpression ?? ""
            self.isEditingExisting = !model.isNew
            if databaseType == .postgresql,
               let match = postgresDataTypeOptions.first(where: { $0.caseInsensitiveCompare(model.dataType) == .orderedSame }) {
                self.selectedDataType = match
            } else {
                self.selectedDataType = nil
            }
        }

        var canSave: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !dataType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

}
// MARK: - Primary Key Editor Sheet

struct PrimaryKeyEditorSheet: View {
    @Binding var primaryKey: TableStructureEditorViewModel.PrimaryKeyModel
    let availableColumns: [String]
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Draft

    init(
        primaryKey: Binding<TableStructureEditorViewModel.PrimaryKeyModel>,
        availableColumns: [String],
        onDelete: @escaping () -> Void,
        onCancelNew: @escaping () -> Void
    ) {
        self._primaryKey = primaryKey
        self.availableColumns = availableColumns
        self.onDelete = onDelete
        self.onCancelNew = onCancelNew
        _draft = State(initialValue: Draft(model: primaryKey.wrappedValue, availableColumns: availableColumns))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                generalSection
                columnsSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            toolbar
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 400)
        .navigationTitle(draft.isEditingExisting ? "Edit Primary Key" : "New Primary Key")
    }

    private var generalSection: some View {
        Section {
            TextField("Constraint Name", text: $draft.name)
        } footer: {
            if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Name is required.")
                    .foregroundStyle(.red)
            }
        }
    }

    private var columnsSection: some View {
        Section {
            ForEach(Array(draft.columns.enumerated()), id: \.element.id) { index, column in
                columnRow(for: binding(for: column.id), index: index)
            }

            HStack {
                Menu {
                    ForEach(addableColumns, id: \.self) { name in
                        Button(name) {
                            addColumn(named: name)
                        }
                    }
                } label: {
                    Label("Add Column", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .disabled(addableColumns.isEmpty)

                Spacer()
            }
        } footer: {
            if draft.columns.isEmpty {
                Text("At least one column is required.")
                    .foregroundStyle(.red)
            } else if addableColumns.isEmpty {
                Text("All available columns are already included.")
            } else {
                Text("Columns use the order shown above.")
            }
        }
    }

    private func columnRow(for column: Binding<Draft.Column>, index: Int) -> some View {
        let columnID = column.wrappedValue.id
        return HStack(spacing: 12) {
            VStack(spacing: 2) {
                Button {
                    moveColumn(at: index, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.borderless)
                .disabled(index == 0)

                Button {
                    moveColumn(at: index, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.borderless)
                .disabled(index == draft.columns.count - 1)
            }
            .frame(width: 24)

            Picker("", selection: column.name) {
                ForEach(columnOptions(for: columnID), id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            Button(role: .destructive) {
                removeColumn(withID: columnID)
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .disabled(draft.columns.count <= 1)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if draft.isEditingExisting {
                Button("Delete Primary Key", role: .destructive) {
                    dismiss()
                    onDelete()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button("Cancel") {
                cancelEditing()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                applyDraft()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!draft.canSave)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func applyDraft() {
        primaryKey.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        primaryKey.columns = draft.columns.map { $0.name }
        dismiss()
    }

    private func cancelEditing() {
        dismiss()
        if !draft.isEditingExisting {
            onCancelNew()
        }
    }

    private func binding(for columnID: UUID) -> Binding<Draft.Column> {
        guard let index = draft.columns.firstIndex(where: { $0.id == columnID }) else {
            fatalError("Column not found")
        }
        return $draft.columns[index]
    }

    private func columnOptions(for columnID: UUID) -> [String] {
        let selectedByOthers = Set(draft.columns.filter { $0.id != columnID }.map { $0.name })
        let options = availableColumns.filter { !selectedByOthers.contains($0) }
        if let current = draft.columns.first(where: { $0.id == columnID })?.name,
           !current.isEmpty,
           !options.contains(current) {
            return (options + [current]).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
        return options.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var addableColumns: [String] {
        availableColumns.filter { name in
            !draft.columns.contains { $0.name == name }
        }.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func addColumn(named name: String) {
        draft.columns.append(.init(name: name))
    }

    private func removeColumn(withID id: UUID) {
        draft.columns.removeAll { $0.id == id }
    }

    private func moveColumn(at index: Int, by offset: Int) {
        let newIndex = index + offset
        guard newIndex >= 0 && newIndex < draft.columns.count else { return }
        draft.columns.move(fromOffsets: IndexSet(integer: index), toOffset: newIndex > index ? newIndex + 1 : newIndex)
    }

    private struct Draft {
        struct Column: Identifiable {
            let id = UUID()
            var name: String
        }

        var name: String
        var columns: [Column]
        let isEditingExisting: Bool

        init(
            model: TableStructureEditorViewModel.PrimaryKeyModel,
            availableColumns: [String]
        ) {
            self.name = model.name
            self.columns = model.columns.map { Column(name: $0) }
            self.isEditingExisting = model.original != nil

            if columns.isEmpty, let first = availableColumns.first {
                self.columns = [Column(name: first)]
            }
        }

        var canSave: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !columns.isEmpty &&
                columns.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }
}

enum BulkColumnEditValue {
    case dataType(String)
    case defaultValue(String?)
    case generatedExpression(String?)
}

// MARK: - Bulk Column Editor

struct BulkColumnEditorSheet: View {
    let mode: TableStructureEditorView.BulkColumnEditorPresentation.Mode
    let columns: [Binding<TableStructureEditorViewModel.ColumnModel>]
    let databaseType: DatabaseType
    let onApply: (BulkColumnEditValue) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var dataType: String = ""
    @State private var defaultValue: String = ""
    @State private var generatedExpression: String = ""
    @State private var selectedPresetType: String? = nil

    init(
        mode: TableStructureEditorView.BulkColumnEditorPresentation.Mode,
        columns: [Binding<TableStructureEditorViewModel.ColumnModel>],
        databaseType: DatabaseType,
        onApply: @escaping (BulkColumnEditValue) -> Void
    ) {
        self.mode = mode
        self.columns = columns
        self.databaseType = databaseType
        self.onApply = onApply

        if let first = columns.first?.wrappedValue {
            switch mode {
            case .dataType:
                if databaseType == .postgresql,
                   let preset = postgresDataTypeOptions.first(where: { $0.caseInsensitiveCompare(first.dataType) == .orderedSame }) {
                    _selectedPresetType = State(initialValue: preset)
                    _dataType = State(initialValue: preset)
                } else {
                    _selectedPresetType = State(initialValue: nil)
                    _dataType = State(initialValue: first.dataType)
                }
            case .defaultValue:
                _selectedPresetType = State(initialValue: nil)
                _defaultValue = State(initialValue: first.defaultValue ?? "")
            case .generatedExpression:
                _selectedPresetType = State(initialValue: nil)
                _generatedExpression = State(initialValue: first.generatedExpression ?? "")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            contentForm

            Divider()

            toolbar
        }
        .frame(minWidth: 360, idealWidth: 420, minHeight: formHeight)
        .background(sheetBackgroundColor)
        .clipShape(sheetShape)
        .overlay(
            sheetShape
                .stroke(sheetBorderColor, lineWidth: 1)
        )
        .shadow(color: sheetShadowColor, radius: 18, y: 10)
        .navigationTitle("Edit Columns")
    }

    private var contentForm: some View {
        Form {
            Section {
                sectionContent
            } header: {
                sectionHeader
            } footer: {
                sectionFooter
            }
            .textCase(nil)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(sheetBackgroundColor)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch mode {
        case .dataType: dataTypeFields
        case .defaultValue: defaultValueField
        case .generatedExpression: generatedExpressionField
        }
    }

    private var dataTypeFields: some View {
        Group {
            labeledRow(title: "Data Type") {
                dataTypePicker
            }

            if needsCustomTypeField {
                labeledRow(title: "Custom Data Type") {
                    inlineField(text: $dataType, alignment: .trailing)
                }
            }
        }
    }

    private var defaultValueField: some View {
        labeledRow(title: "Default Value") {
            inlineField(text: $defaultValue, alignment: .trailing)
        }
    }

    private var generatedExpressionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Generated Expression")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $generatedExpression)
                .font(.system(size: 13))
                .frame(minHeight: 120)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(fieldBackgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(fieldStrokeColor, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(columnSummaryTitle)
                .font(.system(size: 12, weight: .semibold))
            if columnNames.isEmpty {
                Text("No columns selected")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(columnNames.enumerated()), id: \.offset) { _, name in
                    Text("• \(name)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Text(sectionTitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
    }

    private var columnNames: [String] {
        columns.map { $0.wrappedValue.name }
    }

    private var columnSummaryTitle: String {
        let count = columnNames.count
        if count == 0 {
            return "Applying changes"
        } else if count == 1 {
            return "Applying changes to 1 column"
        } else {
            return "Applying changes to \(count) columns"
        }
    }

    private var needsCustomTypeField: Bool {
        mode == .dataType && databaseType == .postgresql && selectedPresetType == nil
    }

    @ViewBuilder
    private var dataTypePicker: some View {
        if databaseType == .postgresql {
            Picker("", selection: presetTypeBinding) {
                ForEach(postgresDataTypeOptions, id: \.self) { option in
                    Text(option).tag(Optional(option))
                }
                Text("Custom…").tag(Optional<String>.none)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 180, alignment: .trailing)
        } else {
            inlineField(text: $dataType, alignment: .trailing)
        }
    }

    private var presetTypeBinding: Binding<String?> {
        Binding(
            get: { selectedPresetType },
            set: { newValue in
                selectedPresetType = newValue
                if let preset = newValue {
                    dataType = preset
                }
            }
        )
    }

    private func inlineField(text: Binding<String>, alignment: TextAlignment) -> some View {
        let frameAlignment: Alignment
        switch alignment {
        case .trailing: frameAlignment = .trailing
        case .center: frameAlignment = .center
        default: frameAlignment = .leading
        }

        return TextField("", text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .multilineTextAlignment(alignment)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    private func labeledRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .frame(minWidth: 120, alignment: .leading)
            Spacer(minLength: 0)
            content()
        }
        .frame(maxWidth: .infinity)
    }

    private var sectionTitle: String {
        switch mode {
        case .dataType: return "Data Type"
        case .defaultValue: return "Default"
        case .generatedExpression: return "Generated Expression"
        }
    }

    @ViewBuilder
    private var sectionFooter: some View {
        switch mode {
        case .dataType:
            EmptyView()
        case .defaultValue, .generatedExpression:
            Text("Leave empty to clear the value on all selected columns.")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Apply") {
                switch mode {
                case .dataType:
                    let resolved: String
                    if databaseType == .postgresql, let preset = selectedPresetType {
                        resolved = preset
                    } else {
                        let trimmed = dataType.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { dismiss(); return }
                        resolved = trimmed
                    }
                    onApply(.dataType(resolved))
                case .defaultValue:
                    let trimmed = defaultValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    onApply(.defaultValue(trimmed.isEmpty ? nil : trimmed))
                case .generatedExpression:
                    let trimmed = generatedExpression.trimmingCharacters(in: .whitespacesAndNewlines)
                    onApply(.generatedExpression(trimmed.isEmpty ? nil : trimmed))
                }
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!canApply)
            .tint(themeManager.accentColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(toolbarBackgroundColor)
        .overlay(
            Rectangle()
                .fill(toolbarBorderColor)
                .frame(height: 1),
            alignment: .top
        )
    }

    private var canApply: Bool {
        switch mode {
        case .dataType:
            if databaseType == .postgresql {
                if let preset = selectedPresetType {
                    return !preset.isEmpty
                }
            }
            return !dataType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .defaultValue, .generatedExpression:
            return true
        }
    }

    private var formHeight: CGFloat {
        switch mode {
        case .dataType:
            return 280
        case .defaultValue:
            return 250
        case .generatedExpression:
            return 360
        }
    }

    private var sheetCornerRadius: CGFloat { 18 }

    private var sheetShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: sheetCornerRadius, style: .continuous)
    }

    private var sheetBackgroundColor: Color {
#if os(macOS)
        Color(nsColor: themeManager.windowBackgroundNSColor)
#else
        themeManager.windowBackgroundColor
#endif
    }

    private var sheetBorderColor: Color {
        let foreground = themeManager.surfaceForegroundColor
        return foreground.opacity(themeManager.effectiveColorScheme == .dark ? 0.2 : 0.08)
    }

    private var sheetShadowColor: Color {
        themeManager.effectiveColorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.16)
    }

    private var fieldBackgroundColor: Color {
#if os(macOS)
        Color(nsColor: themeManager.surfaceBackgroundNSColor).opacity(0.9)
#else
        themeManager.surfaceBackgroundColor.opacity(0.9)
#endif
    }

    private var fieldStrokeColor: Color {
        let foreground = themeManager.surfaceForegroundColor
        return foreground.opacity(themeManager.effectiveColorScheme == .dark ? 0.18 : 0.25)
    }

    private var toolbarBackgroundColor: Color {
#if os(macOS)
        Color(nsColor: themeManager.surfaceBackgroundNSColor)
#else
        themeManager.surfaceBackgroundColor
#endif
    }

    private var toolbarBorderColor: Color {
        themeManager.surfaceForegroundColor.opacity(themeManager.effectiveColorScheme == .dark ? 0.3 : 0.12)
    }
}
// MARK: - Unique Constraint Editor Sheet

struct UniqueConstraintEditorSheet: View {
    @Binding var constraint: TableStructureEditorViewModel.UniqueConstraintModel
    let availableColumns: [String]
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Draft

    init(
        constraint: Binding<TableStructureEditorViewModel.UniqueConstraintModel>,
        availableColumns: [String],
        onDelete: @escaping () -> Void,
        onCancelNew: @escaping () -> Void
    ) {
        self._constraint = constraint
        self.availableColumns = availableColumns
        self.onDelete = onDelete
        self.onCancelNew = onCancelNew
        _draft = State(initialValue: Draft(model: constraint.wrappedValue, availableColumns: availableColumns))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                generalSection
                columnsSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            toolbar
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 400)
        .navigationTitle(draft.isEditingExisting ? "Edit Unique Constraint" : "New Unique Constraint")
    }

    private var generalSection: some View {
        Section {
            TextField("Constraint Name", text: $draft.name)
        } footer: {
            if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Name is required.")
                    .foregroundStyle(.red)
            }
        }
    }

    private var columnsSection: some View {
        Section {
            ForEach(Array(draft.columns.enumerated()), id: \.element.id) { index, column in
                columnRow(for: binding(for: column.id), index: index)
            }

            HStack {
                Menu {
                    ForEach(addableColumns, id: \.self) { name in
                        Button(name) {
                            addColumn(named: name)
                        }
                    }
                } label: {
                    Label("Add Column", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .disabled(addableColumns.isEmpty)

                Spacer()
            }
        } footer: {
            if draft.columns.isEmpty {
                Text("At least one column is required.")
                    .foregroundStyle(.red)
            } else if addableColumns.isEmpty {
                Text("All available columns are already included.")
            } else {
                Text("Columns use the order shown above.")
            }
        }
    }

    private func columnRow(for column: Binding<Draft.Column>, index: Int) -> some View {
        let columnID = column.wrappedValue.id
        return HStack(spacing: 12) {
            VStack(spacing: 2) {
                Button {
                    moveColumn(at: index, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.borderless)
                .disabled(index == 0)

                Button {
                    moveColumn(at: index, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.borderless)
                .disabled(index == draft.columns.count - 1)
            }
            .frame(width: 24)

            Picker("", selection: column.name) {
                ForEach(columnOptions(for: columnID), id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            Button(role: .destructive) {
                removeColumn(withID: columnID)
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .disabled(draft.columns.count <= 1)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if draft.isEditingExisting {
                Button("Delete Constraint", role: .destructive) {
                    dismiss()
                    onDelete()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button("Cancel") {
                cancelEditing()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                applyDraft()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!draft.canSave)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private func applyDraft() {
        constraint.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        constraint.columns = draft.columns.map { $0.name }
        dismiss()
    }

    private func cancelEditing() {
        dismiss()
        if !draft.isEditingExisting {
            onCancelNew()
        }
    }

    private func binding(for columnID: UUID) -> Binding<Draft.Column> {
        guard let index = draft.columns.firstIndex(where: { $0.id == columnID }) else {
            fatalError("Column not found")
        }
        return $draft.columns[index]
    }

    private func columnOptions(for columnID: UUID) -> [String] {
        let selectedByOthers = Set(draft.columns.filter { $0.id != columnID }.map { $0.name })
        let options = availableColumns.filter { !selectedByOthers.contains($0) }
        if let current = draft.columns.first(where: { $0.id == columnID })?.name,
           !current.isEmpty,
           !options.contains(current) {
            return (options + [current]).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
        return options.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var addableColumns: [String] {
        availableColumns.filter { name in
            !draft.columns.contains { $0.name == name }
        }.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func addColumn(named name: String) {
        draft.columns.append(.init(name: name))
    }

    private func removeColumn(withID id: UUID) {
        draft.columns.removeAll { $0.id == id }
    }

    private func moveColumn(at index: Int, by offset: Int) {
        let newIndex = index + offset
        guard newIndex >= 0 && newIndex < draft.columns.count else { return }
        draft.columns.move(fromOffsets: IndexSet(integer: index), toOffset: newIndex > index ? newIndex + 1 : newIndex)
    }

    private struct Draft {
        struct Column: Identifiable {
            let id = UUID()
            var name: String
        }

        var name: String
        var columns: [Column]
        let isEditingExisting: Bool

        init(
            model: TableStructureEditorViewModel.UniqueConstraintModel,
            availableColumns: [String]
        ) {
            self.name = model.name
            self.columns = model.columns.map { Column(name: $0) }
            self.isEditingExisting = model.original != nil

            if columns.isEmpty, let first = availableColumns.first {
                self.columns = [Column(name: first)]
            }
        }

        var canSave: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !columns.isEmpty &&
                columns.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }
}

// MARK: - Foreign Key Editor Sheet

struct ForeignKeyEditorSheet: View {
    @Binding var foreignKey: TableStructureEditorViewModel.ForeignKeyModel
    let availableColumns: [String]
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Draft

    init(
        foreignKey: Binding<TableStructureEditorViewModel.ForeignKeyModel>,
        availableColumns: [String],
        onDelete: @escaping () -> Void,
        onCancelNew: @escaping () -> Void
    ) {
        self._foreignKey = foreignKey
        self.availableColumns = availableColumns
        self.onDelete = onDelete
        self.onCancelNew = onCancelNew
        _draft = State(initialValue: Draft(model: foreignKey.wrappedValue, availableColumns: availableColumns))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                generalSection
                columnsSection
                referenceSection
                actionsSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            toolbar
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 460)
        .navigationTitle(draft.isEditingExisting ? "Edit Foreign Key" : "New Foreign Key")
    }

    private var generalSection: some View {
        Section {
            TextField("Constraint Name", text: $draft.name)

            HStack {
                TextField("Schema", text: $draft.referencedSchema)
                TextField("Table", text: $draft.referencedTable)
            }
        } header: {
            Text("General")
        } footer: {
            VStack(alignment: .leading, spacing: 2) {
                if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Name is required.")
                        .foregroundStyle(.red)
                }
                if draft.referencedTable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Referenced table is required.")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var columnsSection: some View {
        Section {
            ForEach(Array(draft.columns.enumerated()), id: \.element.id) { index, column in
                columnRow(for: binding(for: column.id), index: index)
            }

            HStack {
                Menu {
                    ForEach(addableColumns, id: \.self) { name in
                        Button(name) {
                            addColumn(named: name)
                        }
                    }
                } label: {
                    Label("Add Column", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .disabled(addableColumns.isEmpty)

                Spacer()
            }
        } header: {
            Text("Columns")
        } footer: {
            if draft.columns.isEmpty {
                Text("At least one local column is required.")
                    .foregroundStyle(.red)
            } else if addableColumns.isEmpty {
                Text("All columns are already included.")
            } else {
                Text("Order matches the referenced columns below.")
            }
        }
    }

    private func columnRow(for column: Binding<Draft.Column>, index: Int) -> some View {
        let columnID = column.wrappedValue.id
        return HStack(spacing: 12) {
            VStack(spacing: 2) {
                Button {
                    moveColumn(at: index, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.borderless)
                .disabled(index == 0)

                Button {
                    moveColumn(at: index, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.borderless)
                .disabled(index == draft.columns.count - 1)
            }
            .frame(width: 24)

            Picker("", selection: column.name) {
                ForEach(columnOptions(for: columnID), id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            Button(role: .destructive) {
                removeColumn(withID: columnID)
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .disabled(draft.columns.count <= 1)
        }
    }

    private var referenceSection: some View {
        Section {
            TextField("Referenced Columns", text: $draft.referencedColumnsInput)
        } header: {
            Text("References")
        } footer: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Separate names with commas in the same order as local columns.")
                if draft.referencedColumnsMismatch {
                    Text("Column counts do not match.")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var actionsSection: some View {
        Section {
            TextField("ON UPDATE", text: $draft.onUpdate)
            TextField("ON DELETE", text: $draft.onDelete)
        } header: {
            Text("Actions")
        } footer: {
            Text("Leave blank to use database defaults.")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if draft.isEditingExisting {
                Button("Delete Foreign Key", role: .destructive) {
                    dismiss()
                    onDelete()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button("Cancel") {
                cancelEditing()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                applyDraft()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!draft.canSave)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private func applyDraft() {
        foreignKey.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.columns = draft.columns.map { $0.name }
        foreignKey.referencedSchema = draft.referencedSchema.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.referencedTable = draft.referencedTable.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.referencedColumns = draft.referencedColumns

        let updateTrimmed = draft.onUpdate.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.onUpdate = updateTrimmed.isEmpty ? nil : updateTrimmed

        let deleteTrimmed = draft.onDelete.trimmingCharacters(in: .whitespacesAndNewlines)
        foreignKey.onDelete = deleteTrimmed.isEmpty ? nil : deleteTrimmed

        dismiss()
    }

    private func cancelEditing() {
        dismiss()
        if !draft.isEditingExisting {
            onCancelNew()
        }
    }

    private func binding(for columnID: UUID) -> Binding<Draft.Column> {
        guard let index = draft.columns.firstIndex(where: { $0.id == columnID }) else {
            fatalError("Column not found")
        }
        return $draft.columns[index]
    }

    private func columnOptions(for columnID: UUID) -> [String] {
        let selectedByOthers = Set(draft.columns.filter { $0.id != columnID }.map { $0.name })
        let options = availableColumns.filter { !selectedByOthers.contains($0) }
        if let current = draft.columns.first(where: { $0.id == columnID })?.name,
           !current.isEmpty,
           !options.contains(current) {
            return (options + [current]).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
        return options.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var addableColumns: [String] {
        availableColumns.filter { name in
            !draft.columns.contains { $0.name == name }
        }.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func addColumn(named name: String) {
        draft.columns.append(.init(name: name))
    }

    private func removeColumn(withID id: UUID) {
        draft.columns.removeAll { $0.id == id }
    }

    private func moveColumn(at index: Int, by offset: Int) {
        let newIndex = index + offset
        guard newIndex >= 0 && newIndex < draft.columns.count else { return }
        draft.columns.move(fromOffsets: IndexSet(integer: index), toOffset: newIndex > index ? newIndex + 1 : newIndex)
    }

    private struct Draft {
        struct Column: Identifiable {
            let id = UUID()
            var name: String
        }

        var name: String
        var referencedSchema: String
        var referencedTable: String
        var columns: [Column]
        var referencedColumnsInput: String
        var onUpdate: String
        var onDelete: String
        let isEditingExisting: Bool

        init(
            model: TableStructureEditorViewModel.ForeignKeyModel,
            availableColumns: [String]
        ) {
            self.name = model.name
            self.referencedSchema = model.referencedSchema
            self.referencedTable = model.referencedTable
            self.columns = model.columns.map { Column(name: $0) }
            self.referencedColumnsInput = model.referencedColumns.joined(separator: ", ")
            self.onUpdate = model.onUpdate ?? ""
            self.onDelete = model.onDelete ?? ""
            self.isEditingExisting = model.original != nil

            if columns.isEmpty, let first = availableColumns.first {
                self.columns = [Column(name: first)]
            }
        }

        var referencedColumns: [String] {
            referencedColumnsInput
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        var referencedColumnsMismatch: Bool {
            !columns.isEmpty && referencedColumns.count != columns.count
        }

        var canSave: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !referencedTable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !columns.isEmpty &&
                columns.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }
}

// MARK: - Index Editor Sheet

struct IndexEditorSheet: View {
    @Binding var index: TableStructureEditorViewModel.IndexModel
    let availableColumns: [String]
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Draft

    init(
        index: Binding<TableStructureEditorViewModel.IndexModel>,
        availableColumns: [String],
        onDelete: @escaping () -> Void,
        onCancelNew: @escaping () -> Void
    ) {
        self._index = index
        self.availableColumns = availableColumns
        self.onDelete = onDelete
        self.onCancelNew = onCancelNew
        _draft = State(initialValue: Draft(model: index.wrappedValue, availableColumns: availableColumns))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Form {
                    generalSection
                    columnsSection
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }

            Divider()

            toolbar
        }
        .frame(minWidth: 500, idealWidth: 540, minHeight: 420)
        .navigationTitle(draft.isEditingExisting ? "Edit Index" : "New Index")
    }

    private var generalSection: some View {
        Section {
            LabeledContent("Name") {
                TextField("Index name", text: $draft.name)
            }

            Toggle("Unique", isOn: $draft.isUnique)

            LabeledContent("Filter") {
                TextField("WHERE status = 'active'", text: $draft.filterCondition, axis: .vertical)
                    .lineLimit(3...6)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("General")
        } footer: {
            if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Name is required.")
                    .foregroundStyle(.red)
            } else {
                Text("Filter condition allows creating partial indexes.")
            }
        }
    }

    private var columnsSection: some View {
        Section {
            ForEach(Array(draft.columns.enumerated()), id: \.element.id) { index, column in
                columnRow(for: binding(for: column.id), index: index)
            }

            HStack {
                Menu {
                    ForEach(addableColumns, id: \.self) { columnName in
                        Button(columnName) {
                            addColumn(named: columnName)
                        }
                    }
                } label: {
                    Label("Add Column", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .disabled(addableColumns.isEmpty)

                Spacer()
            }
        } header: {
            Text("Columns")
        } footer: {
            if draft.columns.isEmpty {
                Text("At least one column is required.")
                    .foregroundStyle(.red)
            } else if addableColumns.isEmpty {
                Text("All available columns are already included.")
            } else {
                Text("Columns are indexed in the order shown above. Use arrows to reorder.")
            }
        }
    }

    private func binding(for columnID: UUID) -> Binding<Draft.Column> {
        guard let index = draft.columns.firstIndex(where: { $0.id == columnID }) else {
            fatalError("Column not found")
        }
        return $draft.columns[index]
    }

    private func columnRow(for column: Binding<Draft.Column>, index: Int) -> some View {
        let columnID = column.wrappedValue.id

        return HStack(spacing: 12) {
            VStack(spacing: 2) {
                Button {
                    moveColumn(at: index, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .disabled(index == 0)
                .help("Move up")

                Button {
                    moveColumn(at: index, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .disabled(index == draft.columns.count - 1)
                .help("Move down")
            }
            .frame(width: 20)

            Picker("", selection: column.name) {
                ForEach(columnOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 200)

            Picker("", selection: column.sortOrder) {
                Text("Ascending").tag(TableStructureEditorViewModel.IndexModel.Column.SortOrder.ascending)
                Text("Descending").tag(TableStructureEditorViewModel.IndexModel.Column.SortOrder.descending)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)

            Spacer()

            Button(role: .destructive) {
                removeColumn(withID: columnID)
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .disabled(draft.columns.count <= 1)
            .help("Remove column")
        }
    }

    private func moveColumn(at index: Int, by offset: Int) {
        let newIndex = index + offset
        guard newIndex >= 0 && newIndex < draft.columns.count else { return }
        withAnimation {
            draft.columns.move(fromOffsets: IndexSet(integer: index), toOffset: newIndex > index ? newIndex + 1 : newIndex)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if draft.isEditingExisting {
                Button("Delete Index", role: .destructive) {
                    dismiss()
                    onDelete()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button("Cancel") {
                cancelEditing()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                applyDraft()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!draft.canSave)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private var columnOptions: [String] {
        let current = draft.columns.map(\.name)
        let combined = Set(availableColumns + current)
        return combined.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var addableColumns: [String] {
        availableColumns.filter { name in
            !draft.columns.contains { $0.name == name }
        }.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func addColumn(named name: String) {
        draft.columns.append(.init(name: name, sortOrder: .ascending))
    }

    private func removeColumn(withID id: UUID) {
        draft.columns.removeAll { $0.id == id }
    }

    private func applyDraft() {
        index.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        index.isUnique = draft.isUnique
        index.filterCondition = draft.filterCondition.trimmingCharacters(in: .whitespacesAndNewlines)
        index.columns = draft.columns.map { column in
            TableStructureEditorViewModel.IndexModel.Column(name: column.name, sortOrder: column.sortOrder)
        }
    }

    private func cancelEditing() {
        if draft.isEditingExisting {
            dismiss()
        } else {
            dismiss()
            onCancelNew()
        }
    }

    struct Draft: Identifiable {
        struct Column: Identifiable {
            let id = UUID()
            var name: String
            var sortOrder: TableStructureEditorViewModel.IndexModel.Column.SortOrder
        }

        var id = UUID()
        var name: String
        var isUnique: Bool
        var filterCondition: String
        var columns: [Column]
        let isEditingExisting: Bool

        init(
            model: TableStructureEditorViewModel.IndexModel,
            availableColumns: [String]
        ) {
            self.name = model.name
            self.isUnique = model.isUnique
            self.filterCondition = model.filterCondition
            self.columns = model.columns.map { Column(name: $0.name, sortOrder: $0.sortOrder) }
            self.isEditingExisting = !model.isNew

            if columns.isEmpty {
                let initialName = model.columns.first?.name ?? availableColumns.first ?? ""
                if !initialName.isEmpty {
                    self.columns = [Column(name: initialName, sortOrder: .ascending)]
                }
            }
        }

        var canSave: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !columns.isEmpty && columns.allSatisfy { !$0.name.isEmpty }
        }
    }
}
