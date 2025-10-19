import SwiftUI
import Combine
#if os(macOS)
import AppKit
#else
import UIKit
#endif

private let postgresDataTypeOptions: [String] = [
    "bigint",
    "bigserial",
    "bit",
    "bit varying",
    "boolean",
    "box",
    "bytea",
    "character",
    "character varying",
    "cidr",
    "circle",
    "date",
    "double precision",
    "inet",
    "integer",
    "interval",
    "json",
    "jsonb",
    "line",
    "lseg",
    "macaddr",
    "macaddr8",
    "money",
    "numeric",
    "path",
    "pg_lsn",
    "point",
    "polygon",
    "real",
    "smallint",
    "smallserial",
    "serial",
    "text",
    "time without time zone",
    "time with time zone",
    "timestamp without time zone",
    "timestamp with time zone",
    "tsquery",
    "tsvector",
    "txid_snapshot",
    "uuid",
    "xml"
].sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

struct TableStructureEditorView: View {
    @ObservedObject var tab: WorkspaceTab
    @ObservedObject var viewModel: TableStructureEditorViewModel
    @EnvironmentObject private var appModel: AppModel
    
    @State private var activeIndexEditor: IndexEditorPresentation?
    @State private var activeColumnEditor: ColumnEditorPresentation?
    @State private var activePrimaryKeyEditor: PrimaryKeyEditorPresentation?
    @State private var activeUniqueConstraintEditor: UniqueConstraintEditorPresentation?
    @State private var activeForeignKeyEditor: ForeignKeyEditorPresentation?
    @State private var selectedSection: TableStructureSection
    @State private var selectedColumnIDs: Set<TableStructureEditorViewModel.ColumnModel.ID> = []
    @State private var columnIndexLookup: [UUID: Int] = [:]
    @FocusState private var focusedCustomColumnID: TableStructureEditorViewModel.ColumnModel.ID?
    @State private var bulkColumnEditor: BulkColumnEditorPresentation?
    @EnvironmentObject private var themeManager: ThemeManager

    init(tab: WorkspaceTab, viewModel: TableStructureEditorViewModel) {
        _tab = ObservedObject(initialValue: tab)
        _viewModel = ObservedObject(initialValue: viewModel)
        _selectedSection = State(initialValue: viewModel.requestedSection ?? .columns)
        _columnIndexLookup = State(
            initialValue: Dictionary(
                uniqueKeysWithValues: viewModel.columns.enumerated().map { pair in
                    let (index, column) = pair
                    return (column.id, index)
                }
            )
        )
    }

    private var visibleColumns: [TableStructureEditorViewModel.ColumnModel] {
        viewModel.columns.filter { !$0.isDeleted }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
#if os(macOS)
        .background(Color(nsColor: themeManager.windowBackgroundNSColor))
#else
        .background(themeManager.windowBackgroundColor)
#endif
        .onDisappear {
            viewModel.lastError = nil
            viewModel.lastSuccessMessage = nil
        }
        .onAppear {
            rebuildColumnIndexLookup()
            if let requested = viewModel.requestedSection {
                selectedSection = requested
                viewModel.requestedSection = nil
            }
        }
        .onReceive(viewModel.$columns) { _ in
            pruneSelectedColumns()
            rebuildColumnIndexLookup()
        }
        .onReceive(viewModel.$requestedSection.compactMap { $0 }) { section in
            selectedSection = section
            viewModel.requestedSection = nil
        }
        .sheet(item: $activeIndexEditor) { presentation in
            if let binding = indexBinding(for: presentation.indexID) {
                let isNew = binding.wrappedValue.isNew
                IndexEditorSheet(
                    index: binding,
                    availableColumns: viewModel.columns.filter { !$0.isDeleted }.map { $0.name },
                    onDelete: {
                        let model = binding.wrappedValue
                        viewModel.removeIndex(model)
                        activeIndexEditor = nil
                    },
                    onCancelNew: {
                        guard isNew else { return }
                        let model = binding.wrappedValue
                        viewModel.removeIndex(model)
                    }
                )
            }
        }
        .sheet(item: $activeColumnEditor) { presentation in
            if let binding = columnBinding(for: presentation.columnID) {
                ColumnEditorSheet(
                    column: binding,
                    databaseType: tab.connection.databaseType,
                    onDelete: {
                        let model = binding.wrappedValue
                        viewModel.removeColumn(model)
                        activeColumnEditor = nil
                    },
                    onCancelNew: {
                        guard presentation.isNew else { return }
                        let model = binding.wrappedValue
                        viewModel.removeColumn(model)
                    }
                )
            }
        }
        .sheet(item: $activePrimaryKeyEditor) { presentation in
            if let binding = primaryKeyBinding {
                PrimaryKeyEditorSheet(
                    primaryKey: binding,
                    availableColumns: viewModel.columns.filter { !$0.isDeleted }.map { $0.name },
                    onDelete: {
                        viewModel.removePrimaryKey()
                        activePrimaryKeyEditor = nil
                    },
                    onCancelNew: {
                        guard presentation.isNew else { return }
                        viewModel.primaryKey = nil
                        viewModel.clearPrimaryKeyRemoval()
                    }
                )
            }
        }
        .sheet(item: $activeUniqueConstraintEditor) { presentation in
            if let binding = uniqueConstraintBinding(for: presentation.constraintID) {
                UniqueConstraintEditorSheet(
                    constraint: binding,
                    availableColumns: viewModel.columns.filter { !$0.isDeleted }.map { $0.name },
                    onDelete: {
                        let model = binding.wrappedValue
                        viewModel.removeUniqueConstraint(model)
                        activeUniqueConstraintEditor = nil
                    },
                    onCancelNew: {
                        guard presentation.isNew else { return }
                        let model = binding.wrappedValue
                        viewModel.removeUniqueConstraint(model)
                    }
                )
            }
        }
        .sheet(item: $activeForeignKeyEditor) { presentation in
            if let binding = foreignKeyBinding(for: presentation.foreignKeyID) {
                ForeignKeyEditorSheet(
                    foreignKey: binding,
                    availableColumns: viewModel.columns.filter { !$0.isDeleted }.map { $0.name },
                    onDelete: {
                        let model = binding.wrappedValue
                        viewModel.removeForeignKey(model)
                        activeForeignKeyEditor = nil
                    },
                    onCancelNew: {
                        guard presentation.isNew else { return }
                        let model = binding.wrappedValue
                        viewModel.removeForeignKey(model)
                    }
                )
            }
        }
        .sheet(item: $bulkColumnEditor) { presentation in
            let bindings = presentation.columnIDs.compactMap { columnBinding(for: $0) }
            BulkColumnEditorSheet(
                mode: presentation.mode,
                columns: bindings,
                databaseType: tab.connection.databaseType,
                onApply: { value in
                    applyBulkEdit(mode: presentation.mode, value: value, bindings: bindings)
                }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.schemaName).\(viewModel.tableName)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(headerPrimaryColor)
                    Label(tab.connection.connectionName, systemImage: "externaldrive.connected.to.line.below")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(headerSecondaryColor)
                        .labelStyle(.titleAndIcon)
                }

                Spacer(minLength: 16)

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(accentColor)
                }
            }

            TableStructureTitleView(
                selection: $selectedSection,
                accentColor: accentColor
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(headerBackgroundColor)
        .overlay(
            Rectangle()
                .fill(headerBorderColor)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var content: some View {
        ZStack(alignment: .bottomLeading) {
            ScrollView {
                LazyVStack(alignment: .center, spacing: 20) {
                    if let message = viewModel.lastError {
                        statusMessage(text: message, systemImage: "exclamationmark.triangle.fill", tint: .red)
                    } else if let success = viewModel.lastSuccessMessage {
                        statusMessage(text: success, systemImage: "checkmark.circle.fill", tint: .green)
                    }

                    switch selectedSection {
                    case .columns:
                        columnsSection
                        primaryKeySection
                        uniqueConstraintsSection
                    case .indexes:
                        indexesSection
                    case .relations:
                        foreignKeysSection
                        dependenciesSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 140)
            }

            bottomActionBar
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            reloadButton
            applyButton
            Spacer()
        }
    }

    private func statusMessage(text: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(text)
                .font(.system(size: 12, weight: .medium))
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.palette)
                .foregroundStyle(tint, tint.opacity(0.4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(0.3), lineWidth: 1)
                )
        )
        .frame(maxWidth: 580, alignment: .center)
    }

    private var reloadButton: some View {
        Button {
            Task { await viewModel.reload() }
        } label: {
            HStack(spacing: 10) {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                }

                Text(viewModel.isLoading ? "Reloading…" : "Reload")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(accentColor.opacity(viewModel.isLoading ? 0.18 : 0.1))
                    )
            )
            .overlay(
                Capsule()
                    .stroke(accentColor.opacity(viewModel.isLoading ? 0.65 : 0.35), lineWidth: 1)
            )
            .foregroundColor(accentColor)
            .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isApplying)
        .opacity(viewModel.isApplying ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isApplying)
        .help("Reload table structure")
    }

    private var applyButton: some View {
        let isActive = viewModel.hasPendingChanges || viewModel.isApplying
        let isEnabled = viewModel.hasPendingChanges && !viewModel.isApplying

        return Button(action: applyChanges) {
            HStack(spacing: 10) {
                if viewModel.isApplying {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(applyActiveForegroundColor)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                }

                Text(viewModel.isApplying ? "Applying…" : "Apply")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background {
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                    if isActive {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        accentColor.opacity(0.9),
                                        accentColor.opacity(0.7)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .overlay(
                Capsule()
                    .stroke(
                        isActive ? accentColor.opacity(0.75) : Color.white.opacity(0.2),
                        lineWidth: isActive ? 1.4 : 1
                    )
            )
            .foregroundColor(isActive ? applyActiveForegroundColor : Color.secondary)
            .shadow(color: isActive ? accentColor.opacity(0.4) : Color.black.opacity(0.08), radius: isActive ? 18 : 8, y: isActive ? 10 : 4)
            .scaleEffect(isActive ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: viewModel.hasPendingChanges)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isApplying)
        .keyboardShortcut(.return, modifiers: [.command, .shift])
        .help(isEnabled ? "Apply pending changes (⇧⌘⏎)" : "No changes to apply")
    }

    #if os(macOS)
    private var accentNSColor: NSColor {
        if appModel.useServerColorAsAccent,
           let serverColor = tab.connection.color.nsColor {
            return serverColor
        }
        return NSColor.controlAccentColor
    }

    private var accentColor: Color { Color(nsColor: accentNSColor) }

    private var applyActiveForegroundColor: Color {
        let workingColor = accentNSColor.usingColorSpace(.extendedSRGB) ?? accentNSColor
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        workingColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.6 ? Color.black.opacity(0.85) : Color.white
    }
    #else
    private var accentColor: Color {
        appModel.useServerColorAsAccent ? tab.connection.color : .accentColor
    }

    private var applyActiveForegroundColor: Color {
        guard let cgColor = accentColor.cgColor,
              let srgbSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = cgColor.converted(to: srgbSpace, intent: .defaultIntent, options: nil),
              let components = converted.components else {
            return .white
        }

        let componentCount = converted.numberOfComponents
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat

        if componentCount >= 3 {
            red = components[0]
            green = components[1]
            blue = components[2]
        } else {
            red = components[0]
            green = components[0]
            blue = components[0]
        }

        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.6 ? Color.black.opacity(0.85) : Color.white
    }
    #endif

    private var inlineButtonBackground: Color {
#if os(macOS)
        Color(nsColor: themeManager.surfaceBackgroundNSColor).opacity(0.2)
#else
        themeManager.surfaceBackgroundColor.opacity(0.2)
#endif
    }

    private var headerBackgroundColor: Color {
#if os(macOS)
        Color(nsColor: themeManager.surfaceBackgroundNSColor)
#else
        themeManager.surfaceBackgroundColor
#endif
    }

    private var headerBorderColor: Color {
        themeManager.surfaceForegroundColor.opacity(themeManager.effectiveColorScheme == .dark ? 0.35 : 0.12)
    }

    private var headerPrimaryColor: Color {
        themeManager.surfaceForegroundColor
    }

    private var headerSecondaryColor: Color {
        themeManager.surfaceForegroundColor.opacity(themeManager.effectiveColorScheme == .dark ? 0.7 : 0.55)
    }

    private var columnsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Columns", systemImage: "tablecells")
                    .labelStyle(.titleAndIcon)
                Spacer()
                Button(action: presentNewColumn) {
                    Label("Add Column", systemImage: "plus")
                }
                .controlSize(.small)
            }

            Divider()

            if visibleColumns.isEmpty {
                placeholderText("No columns yet")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 18)
            } else {
                columnsTable
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var columnsTable: some View {
#if os(macOS)
        Table(visibleColumns, selection: $selectedColumnIDs) {
            TableColumn("Name") { column in
                Button { presentColumnEditor(for: column) } label: {
                    Text(column.name)
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .width(ColumnLayout.name)

            TableColumn("Data Type") { column in
                dataTypeCell(for: column, binding: columnBinding(for: column.id))
            }
            .width(ColumnLayout.dataType)

            TableColumn("Allow Null") { column in
                allowNullCell(for: column, binding: columnBinding(for: column.id))
            }
            .width(ColumnLayout.allowNull)

            TableColumn("Default") { column in
                defaultValueCell(for: column, binding: columnBinding(for: column.id))
            }
            .width(ColumnLayout.defaultValue)

            TableColumn("Generated") { column in
                generatedExpressionCell(for: column, binding: columnBinding(for: column.id))
            }
            .width(ColumnLayout.generated)

            TableColumn("Status") { column in
                statusCell(for: column)
            }
            .width(ColumnLayout.status)

            TableColumn("Changes") { column in
                changesCell(for: column)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: TableStructureEditorViewModel.ColumnModel.ID.self) { selection in
            let targets = visibleColumns.filter { selection.contains($0.id) }
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
        .modifier(DisableTableScrolling())
        .frame(height: columnsTableHeight)
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

#if os(macOS)
    @ViewBuilder
    private func dataTypeCell(
        for column: TableStructureEditorViewModel.ColumnModel,
        binding: Binding<TableStructureEditorViewModel.ColumnModel>?
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

                if #available(macOS 13.0, *) {
                    Menu {
                        ForEach(postgresDataTypeOptions, id: \.self) { option in
                            Button(option) { binding.wrappedValue.dataType = option }
                        }
                        Divider()
                        Button("Custom…") { focusedCustomColumnID = column.id }
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
                    .menuIndicator(.hidden)
                } else {
                    Menu {
                        ForEach(postgresDataTypeOptions, id: \.self) { option in
                            Button(option) { binding.wrappedValue.dataType = option }
                        }
                        Divider()
                        Button("Custom…") { focusedCustomColumnID = column.id }
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
            }
        } else {
            Text(column.dataType.uppercased())
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    @ViewBuilder
    private func allowNullCell(for column: TableStructureEditorViewModel.ColumnModel, binding: Binding<TableStructureEditorViewModel.ColumnModel>?) -> some View {
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
    private func defaultValueCell(for column: TableStructureEditorViewModel.ColumnModel, binding: Binding<TableStructureEditorViewModel.ColumnModel>?) -> some View {
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
    private func generatedExpressionCell(for column: TableStructureEditorViewModel.ColumnModel, binding: Binding<TableStructureEditorViewModel.ColumnModel>?) -> some View {
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
    private func statusCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        let metadata = columnStatusMetadata(for: column)
        Label(metadata.title, systemImage: metadata.systemImage)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(metadata.tint)
    }

    @ViewBuilder
    private func changesCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        if let description = columnChangeDescription(for: column) {
            Text(description)
                .foregroundStyle(.secondary)
        } else {
            Text("—")
                .foregroundStyle(Color.secondary.opacity(0.6))
        }
    }

    private var columnsTableHeight: CGFloat {
        let header: CGFloat = 30
        let row: CGFloat = 28
        return max(header + CGFloat(max(visibleColumns.count, 1)) * row, header + row * 3)
    }

    private enum ColumnLayout {
        static let name: CGFloat = 220
        static let dataType: CGFloat = 160
        static let allowNull: CGFloat = 90
        static let defaultValue: CGFloat = 180
        static let generated: CGFloat = 200
        static let status: CGFloat = 120
    }
#else
    private func dataTypeCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        Text(column.dataType.uppercased())
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func allowNullCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        Image(systemName: column.isNullable ? "checkmark.circle" : "xmark.circle")
            .foregroundStyle(column.isNullable ? Color.secondary : Color.primary)
    }

    private func defaultValueCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        Text(column.defaultValue?.isEmpty == false ? column.defaultValue! : "—")
            .foregroundStyle(.secondary)
    }

    private func generatedExpressionCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        Text(column.generatedExpression?.isEmpty == false ? column.generatedExpression! : "—")
            .foregroundStyle(.secondary)
    }

    private func statusCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        let metadata = columnStatusMetadata(for: column)
        Label(metadata.title, systemImage: metadata.systemImage)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(metadata.tint)
    }

    private func changesCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        if let description = columnChangeDescription(for: column) {
            Text(description)
                .foregroundStyle(.secondary)
        } else {
            Text("—")
                .foregroundStyle(Color.secondary.opacity(0.6))
        }
    }
#endif

    private func inlineEditableField(
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
    private struct InlineEditableCell: View {
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
            Color(nsColor: themeManager.surfaceForegroundNSColor)
        }

        private var placeholderColor: Color {
            let nsColor = themeManager.surfaceForegroundNSColor.withAlphaComponent(themeManager.effectiveColorScheme == .dark ? 0.4 : 0.45)
            return Color(nsColor: nsColor)
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

    private struct InlineEditableTextField: NSViewRepresentable {
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
            nsView.textColor = themeManager.surfaceForegroundNSColor

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
    private struct InlineEditableCell: View {
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
    private func columnStatusMetadata(for column: TableStructureEditorViewModel.ColumnModel) -> (title: String, systemImage: String, tint: Color) {
        if column.isNew {
            return ("New", "sparkles", Color.accentColor)
        }
        if column.isDirty {
            return ("Modified", "paintbrush", Color.accentColor)
        }
        return ("Synced", "checkmark.circle", Color.secondary)
    }

    private func columnChangeDescription(for column: TableStructureEditorViewModel.ColumnModel) -> String? {
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

    private func removeColumns(_ columns: [TableStructureEditorViewModel.ColumnModel]) {
        guard !columns.isEmpty else { return }
        columns.forEach { column in
            viewModel.removeColumn(column)
        }
        pruneSelectedColumns()
    }

    private func presentBulkEditor(mode: BulkColumnEditorPresentation.Mode, columns: [TableStructureEditorViewModel.ColumnModel]) {
        guard !columns.isEmpty else { return }
        bulkColumnEditor = BulkColumnEditorPresentation(columnIDs: columns.map(\.id), mode: mode)
    }

    private func applyBulkEdit(
        mode: BulkColumnEditorPresentation.Mode,
        value: BulkColumnEditValue,
        bindings: [Binding<TableStructureEditorViewModel.ColumnModel>]
    ) {
        for binding in bindings {
            switch mode {
            case .dataType:
                if case let .dataType(newType) = value {
                    binding.wrappedValue.dataType = newType
                }
            case .defaultValue:
                if case let .defaultValue(newValue) = value {
                    binding.wrappedValue.defaultValue = newValue
                }
            case .generatedExpression:
                if case let .generatedExpression(newValue) = value {
                    binding.wrappedValue.generatedExpression = newValue
                }
            }
        }

        bulkColumnEditor = nil
    }

    private func pruneSelectedColumns() {
        let valid = Set(visibleColumns.map(\.id))
        selectedColumnIDs = selectedColumnIDs.intersection(valid)
    }

    private func rebuildColumnIndexLookup() {
        columnIndexLookup = Dictionary(
            uniqueKeysWithValues: viewModel.columns.enumerated().map { pair in
                let (index, column) = pair
                return (column.id, index)
            }
        )
    }

    private func presentNewColumn() {
        let model = viewModel.addColumn()
        activeColumnEditor = ColumnEditorPresentation(columnID: model.id, isNew: true)
    }

    private func presentColumnEditor(for column: TableStructureEditorViewModel.ColumnModel) {
        activeColumnEditor = ColumnEditorPresentation(columnID: column.id, isNew: column.isNew)
    }

    private var primaryKeySection: some View {
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

    private var indexesSection: some View {
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

    private var uniqueConstraintsSection: some View {
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

    private var foreignKeysSection: some View {
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

    private var dependenciesSection: some View {
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

    private func columnBinding(for columnID: UUID) -> Binding<TableStructureEditorViewModel.ColumnModel>? {
        guard let index = columnIndexLookup[columnID], index < viewModel.columns.count else { return nil }
        return $viewModel.columns[index]
    }

    private func indexBinding(for indexID: UUID) -> Binding<TableStructureEditorViewModel.IndexModel>? {
        guard let position = viewModel.indexes.firstIndex(where: { $0.id == indexID }) else { return nil }
        return $viewModel.indexes[position]
    }

    private func uniqueConstraintBinding(for constraintID: UUID) -> Binding<TableStructureEditorViewModel.UniqueConstraintModel>? {
        guard let index = viewModel.uniqueConstraints.firstIndex(where: { $0.id == constraintID }) else { return nil }
        return $viewModel.uniqueConstraints[index]
    }

    private func foreignKeyBinding(for foreignKeyID: UUID) -> Binding<TableStructureEditorViewModel.ForeignKeyModel>? {
        guard let index = viewModel.foreignKeys.firstIndex(where: { $0.id == foreignKeyID }) else { return nil }
        return $viewModel.foreignKeys[index]
    }

    private var primaryKeyBinding: Binding<TableStructureEditorViewModel.PrimaryKeyModel>? {
        guard viewModel.primaryKey != nil else { return nil }
        return Binding(
            get: { viewModel.primaryKey! },
            set: { viewModel.primaryKey = $0 }
        )
    }

    private func applyChanges() {
        Task {
            await viewModel.applyChanges()
            if viewModel.lastError == nil {
                await appModel.refreshDatabaseStructure(
                    for: tab.connectionSessionID,
                    scope: .selectedDatabase,
                    databaseOverride: tab.connection.database.isEmpty ? nil : tab.connection.database
                )
            }
        }
    }

    @ViewBuilder
    private func placeholderText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
    }

    private func sectionCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        action: SectionAction? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let action {
                    sectionActionButton(action)
                }
            }

            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
        .frame(maxWidth: 580, alignment: .center)
    }

    @ViewBuilder
    private func sectionActionButton(_ action: SectionAction) -> some View {
        if action.style == .accent {
            Button(action: action.action) {
                sectionActionLabel(for: action)
            }
            .labelStyle(.titleAndIcon)
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
        } else {
            Button(action: action.action) {
                sectionActionLabel(for: action)
            }
            .labelStyle(.titleAndIcon)
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func sectionActionLabel(for action: SectionAction) -> some View {
        if let systemImage = action.systemImage {
            Label(action.title, systemImage: systemImage)
        } else {
            Text(action.title)
        }
    }

    func cardRowBackground(isNew: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(isNew ? 0.35 : 0.2), lineWidth: 0.8)
            )
    }

    private func bubbleLabel(
        _ text: String,
        systemImage: String? = nil,
        tint: Color = Color(nsColor: .unemphasizedSelectedTextBackgroundColor),
        foreground: Color = .secondary,
        subtitle: String? = nil
    ) -> some View {
        HStack(alignment: subtitle == nil ? .center : .top, spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(foreground)
                    .padding(.top, subtitle == nil ? 0 : 1)
            }

            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                Text(text)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(foreground.opacity(0.8))
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, subtitle == nil ? 4 : 6)
        .background(
            Capsule()
                .fill(tint)
        )
        .overlay(
            Capsule()
                .stroke(Color(nsColor: .separatorColor).opacity(0.18))
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    private struct TableStructureTitleView: View {
        @Binding var selection: TableStructureSection
        let accentColor: Color

        var body: some View {
            HStack {
                Spacer()

                Picker("", selection: $selection) {
                    ForEach(TableStructureSection.allCases) { section in
                        Text(section.displayTitle)
                            .tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .tint(accentColor)
                .controlSize(.regular)
                .frame(maxWidth: 340)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private struct ColumnEditorPresentation: Identifiable {
        let columnID: UUID
        let isNew: Bool
        var id: UUID { columnID }
    }

    private struct PrimaryKeyEditorPresentation: Identifiable {
        let id = UUID()
        let isNew: Bool
    }

    private struct UniqueConstraintEditorPresentation: Identifiable {
        let constraintID: UUID
        let isNew: Bool
        var id: UUID { constraintID }
    }

    private struct ForeignKeyEditorPresentation: Identifiable {
        let foreignKeyID: UUID
        let isNew: Bool
        var id: UUID { foreignKeyID }
    }

    private struct IndexEditorPresentation: Identifiable {
        let indexID: UUID
        var id: UUID { indexID }
    }

    fileprivate struct BulkColumnEditorPresentation: Identifiable {
        enum Mode: String, Identifiable {
            case dataType
            case defaultValue
            case generatedExpression

            var id: String { rawValue }
        }

        let id = UUID()
        let columnIDs: [UUID]
        let mode: Mode
    }

    private struct SectionAction {
        enum Style {
            case plain
            case accent
        }

        let title: String
        let systemImage: String?
        let style: Style
        let action: () -> Void

        init(title: String, systemImage: String? = nil, style: Style = .plain, action: @escaping () -> Void) {
            self.title = title
            self.systemImage = systemImage
            self.style = style
            self.action = action
        }
    }
}


private struct DisableTableScrolling: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 13.0, *) {
            content.scrollDisabled(true)
        } else {
            content
        }
    }
}

// MARK: - Column Editor Sheet

private struct ColumnEditorSheet: View {
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

private struct PrimaryKeyEditorSheet: View {
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

fileprivate enum BulkColumnEditValue {
    case dataType(String)
    case defaultValue(String?)
    case generatedExpression(String?)
}

// MARK: - Bulk Column Editor

private struct BulkColumnEditorSheet: View {
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

private struct UniqueConstraintEditorSheet: View {
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

private struct ForeignKeyEditorSheet: View {
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

private struct IndexEditorSheet: View {
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

// MARK: - Layout Helpers

private struct FlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        let availableWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let itemWidth = size.width

            if rowWidth > 0, rowWidth + spacing + itemWidth > availableWidth {
                totalHeight += rowHeight + spacing
                maxRowWidth = max(maxRowWidth, rowWidth)
                rowWidth = 0
                rowHeight = 0
            }

            rowWidth += itemWidth
            rowHeight = max(rowHeight, size.height)
            if subview != subviews.last {
                rowWidth += spacing
            }
        }

        totalHeight += rowHeight
        maxRowWidth = max(maxRowWidth, rowWidth)

        return CGSize(width: min(maxRowWidth, availableWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }

        var origin = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let itemWidth = size.width

            if origin.x > bounds.origin.x, origin.x + itemWidth > bounds.maxX {
                origin.x = bounds.origin.x
                origin.y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: origin.x, y: origin.y), proposal: ProposedViewSize(width: size.width, height: size.height))

            origin.x += itemWidth + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#if os(macOS)
private extension Color {
    var nsColor: NSColor? {
        if let cgColor = self.cgColor {
            return NSColor(cgColor: cgColor)
        }
        return NSColor(self)
    }
}
#endif
