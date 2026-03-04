import SwiftUI
import Combine
#if os(macOS)
import AppKit
#else
import UIKit
#endif

let postgresDataTypeOptions: [String] = [
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
    
    @Environment(ProjectStore.self) private var projectStore
    @EnvironmentObject private var appModel: AppModel
    
    @State internal var activeIndexEditor: IndexEditorPresentation?
    @State internal var activeColumnEditor: ColumnEditorPresentation?
    @State internal var activePrimaryKeyEditor: PrimaryKeyEditorPresentation?
    @State internal var activeUniqueConstraintEditor: UniqueConstraintEditorPresentation?
    @State internal var activeForeignKeyEditor: ForeignKeyEditorPresentation?
    @State internal var selectedSection: TableStructureSection
    @State internal var selectedColumnIDs: Set<TableStructureEditorViewModel.ColumnModel.ID> = []
    @State internal var columnIndexLookup: [UUID: Int] = [:]
    @State internal var selectionAnchor: TableStructureEditorViewModel.ColumnModel.ID?
    @FocusState internal var focusedCustomColumnID: TableStructureEditorViewModel.ColumnModel.ID?
    @State internal var bulkColumnEditor: BulkColumnEditorPresentation?
    @EnvironmentObject internal var themeManager: ThemeManager

    init(tab: WorkspaceTab, viewModel: TableStructureEditorViewModel) {
        _tab = ObservedObject(initialValue: tab)
        _viewModel = ObservedObject(initialValue: viewModel)
        _selectedSection = State(initialValue: viewModel.requestedSection ?? .columns)
        
        // Initialize column index lookup
        _columnIndexLookup = State(
            initialValue: Dictionary(
                uniqueKeysWithValues: viewModel.columns.enumerated().map { pair in
                    let (index, column) = pair
                    return (column.id, index)
                }
            )
        )
    }

    // Direct access to visible columns - no caching
    internal var visibleColumns: [TableStructureEditorViewModel.ColumnModel] {
        viewModel.columns.filter { !$0.isDeleted }
    }
    
    internal var cachedVisibleColumns: [TableStructureEditorViewModel.ColumnModel] {
        viewModel.columns.filter { !$0.isDeleted }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(ColorTokens.Background.primary)
        .task {
            // Lightweight initialization
            if let requested = viewModel.requestedSection {
                selectedSection = requested
                viewModel.requestedSection = nil
            }
        }
        .onChange(of: viewModel.columns) { _, _ in
            // Rebuild lookup when columns change
            rebuildColumnIndexLookup()
            pruneSelectedColumns()
        }
        .sheet(item: $activeIndexEditor) { presentation in
            if let binding = indexBinding(for: presentation.indexID) {
                IndexEditorSheet(
                    index: binding,
                    availableColumns: viewModel.columns.filter { !$0.isDeleted }.map { $0.name },
                    onDelete: {
                        viewModel.removeIndex(binding.wrappedValue)
                        activeIndexEditor = nil
                    },
                    onCancelNew: {
                        if binding.wrappedValue.isNew {
                            viewModel.removeIndex(binding.wrappedValue)
                        }
                        activeIndexEditor = nil
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
                        viewModel.removeColumn(binding.wrappedValue)
                        activeColumnEditor = nil
                    },
                    onCancelNew: {
                        if binding.wrappedValue.isNew {
                            viewModel.removeColumn(binding.wrappedValue)
                        }
                        activeColumnEditor = nil
                    }
                )
            }
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
        if projectStore.globalSettings.useServerColorAsAccent,
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
        projectStore.globalSettings.useServerColorAsAccent ? tab.connection.color : .accentColor
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
        ColorTokens.Background.secondary.opacity(0.2)
    }

    private var headerBackgroundColor: Color {
        ColorTokens.Background.secondary
    }

    private var headerBorderColor: Color {
        ColorTokens.Text.primary.opacity(themeManager.effectiveColorScheme == .dark ? 0.35 : 0.12)
    }

    private var headerPrimaryColor: Color {
        ColorTokens.Text.primary
    }

    private var headerSecondaryColor: Color {
        ColorTokens.Text.primary.opacity(themeManager.effectiveColorScheme == .dark ? 0.7 : 0.55)
    }

    private var columnsSection: some View {
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
    private var columnsHeader: some View {
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

    private func columnRow(for column: TableStructureEditorViewModel.ColumnModel, index: Int) -> some View {
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

    private func updateSelection(with columnID: UUID) {
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

    private func indexOfVisibleColumn(_ id: UUID) -> Int? {
        visibleColumns.firstIndex { $0.id == id }
    }

    private func rowBackgroundColor(for index: Int, isSelected: Bool) -> Color {
        if isSelected {
            return rowSelectedBackgroundColor
        }
        return index.isMultiple(of: 2) ? tableRowPrimaryColor : tableRowAlternateColor
    }

    private var tableBackgroundColor: Color {
        ColorTokens.Background.secondary
    }

    private var tableHeaderBackgroundColor: Color {
        ColorTokens.Background.secondary.opacity(themeManager.effectiveColorScheme == .dark ? 0.9 : 0.96)
    }

    private var tableHeaderTextColor: Color {
        ColorTokens.Text.primary.opacity(themeManager.effectiveColorScheme == .dark ? 0.85 : 0.65)
    }

    private var tableBorderColor: Color {
        ColorTokens.Text.primary.opacity(themeManager.effectiveColorScheme == .dark ? 0.4 : 0.15)
    }

    private var tableDividerColor: Color {
        ColorTokens.Text.primary.opacity(themeManager.effectiveColorScheme == .dark ? 0.35 : 0.1)
    }

    private var tableRowPrimaryColor: Color {
        tableBackgroundColor
    }

    private var tableRowAlternateColor: Color {
        ColorTokens.Background.secondary.opacity(themeManager.effectiveColorScheme == .dark ? 0.78 : 0.99)
    }

    private var rowDividerColor: Color {
        ColorTokens.Text.primary.opacity(themeManager.effectiveColorScheme == .dark ? 0.3 : 0.08)
    }

    private var rowSelectedBackgroundColor: Color {
        themeManager.accentColor.opacity(themeManager.effectiveColorScheme == .dark ? 0.38 : 0.2)
    }

    @ViewBuilder
    private func dataTypeCell(
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
        if let anchor = selectionAnchor, !valid.contains(anchor) {
            selectionAnchor = selectedColumnIDs.first
        }
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

    internal func presentColumnEditor(for column: TableStructureEditorViewModel.ColumnModel) {
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

    internal func columnBinding(for columnID: UUID) -> Binding<TableStructureEditorViewModel.ColumnModel>? {
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

    internal struct ColumnEditorPresentation: Identifiable {
        let columnID: UUID
        let isNew: Bool
        var id: UUID { columnID }
    }

    internal struct PrimaryKeyEditorPresentation: Identifiable {
        let id = UUID()
        let isNew: Bool
    }

    internal struct UniqueConstraintEditorPresentation: Identifiable {
        let constraintID: UUID
        let isNew: Bool
        var id: UUID { constraintID }
    }

    internal struct ForeignKeyEditorPresentation: Identifiable {
        let foreignKeyID: UUID
        let isNew: Bool
        var id: UUID { foreignKeyID }
    }

    internal struct IndexEditorPresentation: Identifiable {
        let indexID: UUID
        var id: UUID { indexID }
    }

    struct BulkColumnEditorPresentation: Identifiable {
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
