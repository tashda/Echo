import SwiftUI

extension TableStructureEditorView {
    
    internal var columnsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            modernColumnsHeader
            adaptiveColumnsTable
        }
        .padding(.vertical, 6)
    }
    
    private var modernColumnsHeader: some View {
        HStack(spacing: 12) {
            Label("Columns", systemImage: "tablecells")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 15, weight: .semibold))
            
            if !selectedColumnIDs.isEmpty {
                Text("(\(selectedColumnIDs.count) selected)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if !selectedColumnIDs.isEmpty {
                    Menu {
                        let targets = selectedColumnIDs.compactMap { id in
                            visibleColumns.first(where: { $0.id == id })
                        }
                        
                        if targets.count > 1 {
                            Button("Edit Data Type") { 
                                presentBulkEditor(mode: .dataType, columns: targets) 
                            }
                            Button("Edit Default Value") { 
                                presentBulkEditor(mode: .defaultValue, columns: targets) 
                            }
                            Button("Edit Generated Expression") { 
                                presentBulkEditor(mode: .generatedExpression, columns: targets) 
                            }
                            Divider()
                        }
                        
                        Button("Remove Selected", role: .destructive) {
                            removeColumns(targets)
                        }
                    } label: {
                        Label("Actions", systemImage: "ellipsis.circle")
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                }
                
                Button(action: presentNewColumn) {
                    Label("Add Column", systemImage: "plus")
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    internal var columnsTable: some View {
#if os(macOS)
        VStack(spacing: 0) {
            columnsHeader
            Divider()
                .background(tableDividerColor)

            LazyVStack(spacing: 0) {
                ForEach(Array(visibleColumns.enumerated()), id: \.element.id) { index, column in
                    columnRow(for: column, index: index)
                        .background(rowBackgroundColor(for: index, isSelected: selectedColumnIDs.contains(column.id)))
                }
            }
        }
        .background(tableBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tableBorderColor, lineWidth: 1)
        )
#else
        List(visibleColumns) { column in
            VStack(alignment: .leading, spacing: 4) {
                Text(column.name)
                    .font(.system(size: 15, weight: .semibold))
                Text(column.dataType.uppercased())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let description = columnChangeDescription(for: column) {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .contextMenu {
                Button("Edit Column", action: { presentColumnEditor(for: column) })
                Button("Remove Column", role: .destructive) { viewModel.removeColumn(column) }
            }
        }
#endif
    }

#if os(macOS)
    internal var columnsHeader: some View {
        HStack(spacing: 0) {
            headerLabel("Name", width: ColumnLayout.name, alignment: .leading)
            headerLabel("Data Type", width: ColumnLayout.dataType, alignment: .leading)
            headerLabel("Allow Null", width: ColumnLayout.allowNull, alignment: .center)
            headerLabel("Default", width: ColumnLayout.defaultValue, alignment: .trailing)
            headerLabel("Generated", width: ColumnLayout.generated, alignment: .trailing)
            headerLabel("Status", width: ColumnLayout.status, alignment: .leading)
            Text("Changes")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(tableHeaderTextColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(tableHeaderBackgroundColor)
    }

    private func headerLabel(_ title: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(title)
            .frame(width: width, alignment: alignment)
    }

    internal func columnRow(for column: TableStructureEditorViewModel.ColumnModel, index: Int) -> some View {
        let binding = columnBinding(for: column.id)
        let isSelected = selectedColumnIDs.contains(column.id)
        let shouldShowMenu = isSelected || selectionAnchor == column.id || focusedCustomColumnID == column.id

        return HStack(spacing: 0) {
            Text(column.name)
                .font(.system(size: 13))
                .frame(width: ColumnLayout.name, alignment: .leading)
                .padding(.vertical, 1)
                .padding(.leading, 4)

            dataTypeCell(for: column, binding: binding, isMenuVisible: shouldShowMenu)
                .frame(width: ColumnLayout.dataType, alignment: .leading)
                .padding(.horizontal, 8)

            allowNullCell(for: column, binding: binding)
                .frame(width: ColumnLayout.allowNull, alignment: .center)

            defaultValueCell(for: column, binding: binding)
                .frame(width: ColumnLayout.defaultValue, alignment: .trailing)
                .padding(.horizontal, 8)

            generatedExpressionCell(for: column, binding: binding)
                .frame(width: ColumnLayout.generated, alignment: .trailing)
                .padding(.horizontal, 8)

            statusCell(for: column)
                .frame(width: ColumnLayout.status, alignment: .leading)
                .padding(.horizontal, 8)

            changesCell(for: column)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
        }
        .padding(.vertical, 6)
        .overlay(
            Rectangle()
                .fill(rowDividerColor)
                .frame(height: 1),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture {
            updateSelection(with: column.id)
        }
        .onTapGesture(count: 2) {
            presentColumnEditor(for: column)
        }
        .contextMenu {
            let targets = contextMenuTargets(for: column)
            if let first = targets.first, targets.count == 1 {
                Button("Edit Column") { presentColumnEditor(for: first) }
            }
            if targets.count > 1 {
                Menu("Edit Columns") {
                    Button("Edit Data Type") { presentBulkEditor(mode: .dataType, columns: targets) }
                    Button("Edit Default Value") { presentBulkEditor(mode: .defaultValue, columns: targets) }
                    Button("Edit Generated Expression") { presentBulkEditor(mode: .generatedExpression, columns: targets) }
                }
            }
            if !targets.isEmpty {
                let title = targets.count == 1 ? "Remove Column" : "Remove Columns"
                Button(title, role: .destructive) { removeColumns(targets) }
            }
        }
        .background(rowBackgroundColor(for: index, isSelected: isSelected))
    }

    internal func updateSelection(with columnID: UUID) {
#if os(macOS)
        if let event = NSApp.currentEvent {
            let modifiers = event.modifierFlags
            if modifiers.contains(.command) {
                if selectedColumnIDs.contains(columnID) {
                    selectedColumnIDs.remove(columnID)
                    if selectionAnchor == columnID {
                        selectionAnchor = selectedColumnIDs.first
                    }
                } else {
                    selectedColumnIDs.insert(columnID)
                    selectionAnchor = columnID
                }
                return
            }

            if modifiers.contains(.shift), let anchor = selectionAnchor,
               let anchorIndex = indexOfVisibleColumn(anchor),
               let currentIndex = indexOfVisibleColumn(columnID) {
                let range = anchorIndex <= currentIndex ? anchorIndex...currentIndex : currentIndex...anchorIndex
                let ids = range.map { visibleColumns[$0].id }
                selectedColumnIDs = Set(ids)
                return
            }
        }
#endif
        selectedColumnIDs = [columnID]
        selectionAnchor = columnID
    }

    internal func contextMenuTargets(for column: TableStructureEditorViewModel.ColumnModel) -> [TableStructureEditorViewModel.ColumnModel] {
        if selectedColumnIDs.contains(column.id) {
            let selected = selectedColumnIDs
            return visibleColumns.filter { selected.contains($0.id) }
        } else {
            return [column]
        }
    }

    internal func indexOfVisibleColumn(_ id: UUID) -> Int? {
        visibleColumns.firstIndex { $0.id == id }
    }

    internal func rowBackgroundColor(for index: Int, isSelected: Bool) -> Color {
        if isSelected {
            return rowSelectedBackgroundColor
        }
        return index.isMultiple(of: 2) ? tableRowPrimaryColor : tableRowAlternateColor
    }

    internal var tableBackgroundColor: Color {
        ColorTokens.Background.secondary
    }

    internal var tableHeaderBackgroundColor: Color {
        ColorTokens.Background.secondary.opacity(themeManager.effectiveColorScheme == .dark ? 0.9 : 0.96)
    }

    internal var tableHeaderTextColor: Color {
        ColorTokens.Text.primary.opacity(themeManager.effectiveColorScheme == .dark ? 0.85 : 0.65)
    }

    internal var tableBorderColor: Color {
        ColorTokens.Text.primary.opacity(themeManager.effectiveColorScheme == .dark ? 0.4 : 0.15)
    }

    internal var tableDividerColor: Color {
        ColorTokens.Text.primary.opacity(themeManager.effectiveColorScheme == .dark ? 0.35 : 0.1)
    }

    internal var tableRowPrimaryColor: Color {
        tableBackgroundColor
    }

    internal var tableRowAlternateColor: Color {
        ColorTokens.Background.secondary.opacity(themeManager.effectiveColorScheme == .dark ? 0.78 : 0.99)
    }

    internal var rowDividerColor: Color {
        ColorTokens.Text.primary.opacity(themeManager.effectiveColorScheme == .dark ? 0.3 : 0.08)
    }

    internal var rowSelectedBackgroundColor: Color {
        themeManager.accentColor.opacity(themeManager.effectiveColorScheme == .dark ? 0.38 : 0.2)
    }

    @ViewBuilder
    internal func dataTypeCell(
        for column: TableStructureEditorViewModel.ColumnModel,
        binding: Binding<TableStructureEditorViewModel.ColumnModel>?,
        isMenuVisible: Bool
    ) -> some View {
        if let binding {
            HStack(spacing: 4) {
                inlineEditableField(
                    text: Binding(
                        get: { binding.wrappedValue.dataType },
                        set: { binding.wrappedValue.dataType = $0 }
                    ),
                    placeholder: "Data Type",
                    alignment: .leading
                )
                .focused($focusedCustomColumnID, equals: column.id)

                if isMenuVisible {
                    dataTypeMenuButton(for: column, binding: binding)
                }
            }
        } else {
            Text(column.dataType.uppercased())
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func dataTypeMenuButton(
        for column: TableStructureEditorViewModel.ColumnModel,
        binding: Binding<TableStructureEditorViewModel.ColumnModel>
    ) -> some View {
        if #available(macOS 13.0, *) {
            dataTypeMenuBase(for: column, binding: binding)
                .menuIndicator(.hidden)
        } else {
            dataTypeMenuBase(for: column, binding: binding)
        }
    }

    private func dataTypeMenuBase(
        for column: TableStructureEditorViewModel.ColumnModel,
        binding: Binding<TableStructureEditorViewModel.ColumnModel>
    ) -> some View {
        Menu {
            dataTypeMenuItems(for: column, binding: binding)
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.vertical, 3)
                .padding(.horizontal, 5)
                .background(inlineButtonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private func dataTypeMenuItems(
        for column: TableStructureEditorViewModel.ColumnModel,
        binding: Binding<TableStructureEditorViewModel.ColumnModel>
    ) -> some View {
        ForEach(postgresDataTypeOptions, id: \.self) { option in
            Button(option) { binding.wrappedValue.dataType = option }
        }
        Divider()
        Button("Custom…") { focusedCustomColumnID = column.id }
    }
    @ViewBuilder
    internal func allowNullCell(for column: TableStructureEditorViewModel.ColumnModel, binding: Binding<TableStructureEditorViewModel.ColumnModel>?) -> some View {
        if let binding {
            Toggle("", isOn: binding.isNullable)
                .toggleStyle(.checkbox)
                .labelsHidden()
        } else {
            Toggle("", isOn: .constant(column.isNullable))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(true)
        }
    }

    @ViewBuilder
    internal func defaultValueCell(for column: TableStructureEditorViewModel.ColumnModel, binding: Binding<TableStructureEditorViewModel.ColumnModel>?) -> some View {
        if let binding {
            inlineEditableField(
                text: Binding(
                    get: { binding.wrappedValue.defaultValue ?? "" },
                    set: { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        binding.wrappedValue.defaultValue = trimmed.isEmpty ? nil : trimmed
                    }
                ),
                placeholder: "—",
                alignment: .trailing
            )
        } else {
            Text(column.defaultValue?.isEmpty == false ? column.defaultValue! : "—")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    internal func generatedExpressionCell(for column: TableStructureEditorViewModel.ColumnModel, binding: Binding<TableStructureEditorViewModel.ColumnModel>?) -> some View {
        if let binding {
            inlineEditableField(
                text: Binding(
                    get: { binding.wrappedValue.generatedExpression ?? "" },
                    set: { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        binding.wrappedValue.generatedExpression = trimmed.isEmpty ? nil : trimmed
                    }
                ),
                placeholder: "—",
                alignment: .trailing
            )
        } else {
            Text(column.generatedExpression?.isEmpty == false ? column.generatedExpression! : "—")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    internal func statusCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        let metadata = columnStatusMetadata(for: column)
        Label(metadata.title, systemImage: metadata.systemImage)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(metadata.tint)
    }

    @ViewBuilder
    internal func changesCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        if let description = columnChangeDescription(for: column) {
            Text(description)
                .foregroundStyle(.secondary)
        } else {
            Text("—")
                .foregroundStyle(Color.secondary.opacity(0.6))
        }
    }

    internal enum ColumnLayout {
        static let name: CGFloat = 220
        static let dataType: CGFloat = 160
        static let allowNull: CGFloat = 90
        static let defaultValue: CGFloat = 180
        static let generated: CGFloat = 200
        static let status: CGFloat = 120
    }
#else
    internal func dataTypeCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        Text(column.dataType.uppercased())
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    internal func allowNullCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        Image(systemName: column.isNullable ? "checkmark.circle" : "xmark.circle")
            .foregroundStyle(column.isNullable ? Color.secondary : Color.primary)
    }

    internal func defaultValueCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        Text(column.defaultValue?.isEmpty == false ? column.defaultValue! : "—")
            .foregroundStyle(.secondary)
    }

    internal func generatedExpressionCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        Text(column.generatedExpression?.isEmpty == false ? column.generatedExpression! : "—")
            .foregroundStyle(.secondary)
    }

    internal func statusCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        let metadata = columnStatusMetadata(for: column)
        Label(metadata.title, systemImage: metadata.systemImage)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(metadata.tint)
    }

    internal func changesCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        if let description = columnChangeDescription(for: column) {
            Text(description)
                .foregroundStyle(.secondary)
        } else {
            Text("—")
                .foregroundStyle(Color.secondary.opacity(0.6))
        }
    }
#endif

    internal func inlineEditableField(
        text: Binding<String>,
        placeholder: String,
        alignment: TextAlignment
    ) -> some View {
        InlineEditableCell(
            value: text,
            placeholder: placeholder,
            alignment: alignment,
            themeManager: themeManager
        )
    }

#if os(macOS)
    internal struct InlineEditableCell: View {
        @Binding var value: String
        let placeholder: String
        let alignment: TextAlignment
        let themeManager: ThemeManager

        @State private var isEditing = false
        @State private var workingValue: String = ""
        @State private var focusSession: Int = 0

        private var swiftAlignment: Alignment {
            switch alignment {
            case .trailing: return .trailing
            case .center: return .center
            default: return .leading
            }
        }

        private var textAlignment: NSTextAlignment {
            switch alignment {
            case .trailing: return .right
            case .center: return .center
            default: return .left
            }
        }

        private var textColor: Color {
            ColorTokens.Text.primary
        }

        private var placeholderColor: Color {
            ColorTokens.Text.primary.opacity(themeManager.effectiveColorScheme == .dark ? 0.4 : 0.45)
        }

        private var displayValue: String {
            value
        }

        private var isValueEmpty: Bool {
            displayValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var body: some View {
            ZStack(alignment: swiftAlignment) {
                if isEditing {
                    InlineEditableTextField(
                        text: $workingValue,
                        alignment: textAlignment,
                        themeManager: themeManager,
                        focusSession: focusSession,
                        onCommit: commit,
                        onCancel: cancel
                    )
                    .frame(maxWidth: .infinity, alignment: swiftAlignment)
                } else {
                    if isValueEmpty {
                        Text(placeholder)
                            .foregroundStyle(placeholderColor)
                            .frame(maxWidth: .infinity, alignment: swiftAlignment)
                    } else {
                        Text(displayValue)
                            .foregroundStyle(textColor)
                            .frame(maxWidth: .infinity, alignment: swiftAlignment)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: swiftAlignment)
            .contentShape(Rectangle())
            .onTapGesture {
                beginEditing()
            }
        }

        private func beginEditing() {
            workingValue = value
            focusSession &+= 1
            isEditing = true
        }

        private func commit(_ newValue: String) {
            value = newValue
            workingValue = newValue
            isEditing = false
        }

        private func cancel() {
            workingValue = value
            isEditing = false
        }
    }

    internal struct InlineEditableTextField: NSViewRepresentable {
        @Binding var text: String
        let alignment: NSTextAlignment
        let themeManager: ThemeManager
        let focusSession: Int
        let onCommit: (String) -> Void
        let onCancel: () -> Void

        func makeCoordinator() -> Coordinator {
            Coordinator(parent: self)
        }

        func makeNSView(context: Context) -> NSTextField {
            let field = NSTextField()
            field.isBordered = false
            field.drawsBackground = false
            field.font = NSFont.systemFont(ofSize: 12)
            field.alignment = alignment
            field.delegate = context.coordinator
            field.focusRingType = .none
            field.lineBreakMode = .byTruncatingTail
            field.translatesAutoresizingMaskIntoConstraints = false
            return field
        }

        func updateNSView(_ nsView: NSTextField, context: Context) {
            context.coordinator.parent = self

            if nsView.stringValue != text {
                nsView.stringValue = text
            }

            nsView.alignment = alignment
            nsView.font = NSFont.systemFont(ofSize: 12)
            nsView.textColor = NSColor(ColorTokens.Text.primary)

            if context.coordinator.lastFocusSession != focusSession {
                context.coordinator.lastFocusSession = focusSession
                DispatchQueue.main.async {
                    nsView.window?.makeFirstResponder(nsView)
                    if let editor = nsView.currentEditor() {
                        editor.selectedRange = NSRange(location: 0, length: (nsView.stringValue as NSString).length)
                    }
                }
            }
        }

        final class Coordinator: NSObject, NSTextFieldDelegate {
            var parent: InlineEditableTextField
            var lastFocusSession: Int = -1
            private var didHandleCommand = false

            init(parent: InlineEditableTextField) {
                self.parent = parent
            }

            func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
                switch commandSelector {
                case #selector(NSResponder.cancelOperation(_:)):
                    didHandleCommand = true
                    parent.onCancel()
                    return true
                case #selector(NSResponder.insertNewline(_:)):
                    didHandleCommand = true
                    parent.onCommit(control.stringValue)
                    return true
                default:
                    return false
                }
            }

            func controlTextDidEndEditing(_ notification: Notification) {
                guard let field = notification.object as? NSTextField else { return }
                if didHandleCommand {
                    didHandleCommand = false
                    return
                }
                parent.onCommit(field.stringValue)
            }
        }
    }
#else
    internal struct InlineEditableCell: View {
        @Binding var value: String
        let placeholder: String
        let alignment: TextAlignment
        let themeManager: ThemeManager

        var body: some View {
            TextField(placeholder, text: $value)
                .multilineTextAlignment(alignment)
                .textFieldStyle(.plain)
        }
    }
#endif

    internal func columnStatusMetadata(for column: TableStructureEditorViewModel.ColumnModel) -> (title: String, systemImage: String, tint: Color) {
        if column.isNew {
            return ("New", "sparkles", Color.accentColor)
        }
        if column.isDirty {
            return ("Modified", "paintbrush", Color.accentColor)
        }
        return ("Synced", "checkmark.circle", Color.secondary)
    }

    internal func columnChangeDescription(for column: TableStructureEditorViewModel.ColumnModel) -> String? {
        var parts: [String] = []

        if column.hasRename, let previous = column.original?.name {
            parts.append("Renamed from \(previous)")
        }
        if column.hasTypeChange, let previous = column.original?.dataType {
            parts.append("Type changed from \(previous)")
        }
        if column.hasNullabilityChange {
            parts.append(column.isNullable ? "Now allows NULL" : "Now disallows NULL")
        }
        if column.hasDefaultChange {
            let previous = column.original?.defaultValue?.isEmpty == false ? column.original!.defaultValue! : "None"
            let current = column.defaultValue?.isEmpty == false ? column.defaultValue! : "None"
            parts.append("Default: \(previous) → \(current)")
        }
        if column.hasExpressionChange {
            parts.append("Generated expression updated")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    internal func removeColumns(_ columns: [TableStructureEditorViewModel.ColumnModel]) {
        guard !columns.isEmpty else { return }
        columns.forEach { column in
            viewModel.removeColumn(column)
        }
        pruneSelectedColumns()
    }

    internal func presentBulkEditor(mode: BulkColumnEditorPresentation.Mode, columns: [TableStructureEditorViewModel.ColumnModel]) {
        guard !columns.isEmpty else { return }
        bulkColumnEditor = BulkColumnEditorPresentation(mode: mode, columnIDs: columns.map(\.id))
    }

    internal func pruneSelectedColumns() {
        let valid = Set(visibleColumns.map(\.id))
        selectedColumnIDs = selectedColumnIDs.intersection(valid)
        if let anchor = selectionAnchor, !valid.contains(anchor) {
            selectionAnchor = selectedColumnIDs.first
        }
    }

    internal func rebuildColumnIndexLookup() {
        columnIndexLookup = Dictionary(
            uniqueKeysWithValues: viewModel.columns.enumerated().map { pair in
                let (index, column) = pair
                return (column.id, index)
            }
        )
    }

    internal func presentNewColumn() {
        let model = viewModel.addColumn()
        activeColumnEditor = ColumnEditorPresentation(columnID: model.id, isNew: true)
    }

    internal func presentColumnEditor(for column: TableStructureEditorViewModel.ColumnModel) {
        activeColumnEditor = ColumnEditorPresentation(columnID: column.id, isNew: column.isNew)
    }
}
