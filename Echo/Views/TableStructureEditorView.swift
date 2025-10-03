import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct TableStructureEditorView: View {
    @ObservedObject var tab: WorkspaceTab
    @ObservedObject var viewModel: TableStructureEditorViewModel
    @EnvironmentObject private var appModel: AppModel

    @State private var activeIndexEditor: IndexEditorPresentation?
    @State private var activeColumnEditor: ColumnEditorPresentation?
    @State private var activePrimaryKeyEditor: PrimaryKeyEditorPresentation?
    @State private var activeUniqueConstraintEditor: UniqueConstraintEditorPresentation?
    @State private var activeForeignKeyEditor: ForeignKeyEditorPresentation?
    @State private var selectedSection: TableStructureSection = .columns

    private var columnGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 16, alignment: .top)]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear {
            viewModel.lastError = nil
            viewModel.lastSuccessMessage = nil
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.schemaName).\(viewModel.tableName)")
                        .font(.system(size: 18, weight: .semibold))
                    Label(tab.connection.connectionName, systemImage: "externaldrive.connected.to.line.below")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
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
                            .fill(viewModel.isLoading ? accentColor.opacity(0.12) : Color.clear)
                    )
            )
            .overlay(
                Capsule()
                    .stroke(viewModel.isLoading ? accentColor.opacity(0.55) : Color.white.opacity(0.25), lineWidth: 1)
            )
            .foregroundStyle(viewModel.isLoading ? accentColor : Color.primary.opacity(0.75))
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
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
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
                    .opacity(isActive ? 1 : 0)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isActive ? accentColor.opacity(0.75) : Color.white.opacity(0.2),
                        lineWidth: isActive ? 1.4 : 1
                    )
            )
            .foregroundStyle(isActive ? applyActiveForegroundColor : Color.secondary)
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

    private var columnsSection: some View {
        sectionCard(
            title: "Columns",
            subtitle: "Field definitions",
            systemImage: "tablecells",
            action: SectionAction(title: "Add Column", systemImage: "plus", style: .accent) {
                presentNewColumn()
            }
        ) {
            if viewModel.columns.contains(where: { !$0.isDeleted }) {
                LazyVGrid(columns: columnGridColumns, spacing: 16) {
                    ForEach(viewModel.columns.filter { !$0.isDeleted }) { model in
                        columnCard(model)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                placeholderText("No columns yet")
            }
        }
    }

    private func columnCard(_ column: TableStructureEditorViewModel.ColumnModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(column.name)
                        .font(.system(size: 15, weight: .semibold))

                    Text(column.dataType.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 6) {
                    columnStatusBadge(for: column)

                    if column.hasRename, let previous = column.original?.name {
                        changeChip("Renamed from \(previous)", icon: "arrow.triangle.2.circlepath", tint: Color.orange)
                    }
                }

                Menu {
                    Button("Edit Column", action: { presentColumnEditor(for: column) })
                    Button("Remove Column", role: .destructive, action: { viewModel.removeColumn(column) })
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Divider()
                .opacity(0.08)

            VStack(alignment: .leading, spacing: 8) {
                columnDetailRow(
                    text: column.isNullable ? "Allows NULL values" : "Required",
                    systemImage: column.isNullable ? "checkmark.circle" : "exclamationmark.triangle",
                    color: column.isNullable ? accentColor : Color.red
                )

                if let defaultValue = column.defaultValue, !defaultValue.isEmpty {
                    columnDetailRow(
                        text: "Default: \(defaultValue)",
                        systemImage: "equal",
                        color: Color.secondary
                    )
                }

                if let expression = column.generatedExpression, !expression.isEmpty {
                    columnDetailRow(
                        text: "Generated: \(expression)",
                        systemImage: "function",
                        color: Color.secondary
                    )
                }

                columnChangeSummary(for: column)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(columnCardBackground(for: column))
    }

    @ViewBuilder
    private func columnStatusBadge(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        if column.isNew {
            changeChip("New", icon: "sparkles", tint: accentColor)
        } else if column.isDirty {
            changeChip("Modified", icon: "paintbrush", tint: accentColor)
        } else {
            changeChip("Synced", icon: "checkmark.circle", tint: Color.secondary)
        }
    }

    private func columnDetailRow(text: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.85))
        }
    }

    @ViewBuilder
    private func columnChangeSummary(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        let items = columnChangeItems(for: column)
        if !items.isEmpty {
            FlowLayout(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    changeChip(item.text, icon: item.icon, tint: item.tint)
                }
            }
        }
    }

    private func columnChangeItems(for column: TableStructureEditorViewModel.ColumnModel) -> [(text: String, icon: String, tint: Color)] {
        var items: [(String, String, Color)] = []
        if column.hasTypeChange, let previous = column.original?.dataType {
            items.append(("Type was \(previous)", "clock.arrow.circlepath", accentColor))
        }
        if column.hasNullabilityChange {
            items.append(("Nullability updated", "exclamationmark.arrow.triangle.2.circlepath", accentColor))
        }
        if column.hasDefaultChange {
            items.append(("Default updated", "arrow.uturn.down", accentColor))
        }
        if column.hasExpressionChange {
            items.append(("Expression updated", "arrow.uturn.up", accentColor))
        }
        return items
    }

    private func columnCardBackground(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(columnBorderColor(for: column), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
    }

    private func columnBorderColor(for column: TableStructureEditorViewModel.ColumnModel) -> Color {
        if column.isNew {
            return accentColor.opacity(0.35)
        } else if column.isDirty {
            return accentColor.opacity(0.25)
        } else {
            return Color(nsColor: .separatorColor).opacity(0.25)
        }
    }

    private func changeChip(_ text: String, icon: String, tint: Color) -> some View {
        bubbleLabel(
            text,
            systemImage: icon,
            tint: tint.opacity(0.14),
            foreground: tint.opacity(0.9)
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
            systemImage: "hierarchy"
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
        guard let index = viewModel.columns.firstIndex(where: { $0.id == columnID }) else { return nil }
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

    fileprivate enum TableStructureSection: String, CaseIterable, Identifiable {
        case columns
        case indexes
        case relations

        var id: String { rawValue }

        var displayTitle: String {
            switch self {
            case .columns:
                return "Columns"
            case .indexes:
                return "Indexes"
            case .relations:
                return "Relations"
            }
        }

        var order: Int {
            switch self {
            case .columns: return 0
            case .indexes: return 1
            case .relations: return 2
            }
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

// MARK: - Column Editor Sheet

private struct ColumnEditorSheet: View {
    @Binding var column: TableStructureEditorViewModel.ColumnModel
    let databaseType: DatabaseType
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) private var dismiss
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
            ZStack {
                sheetBackgroundColor
                Form {
                    generalSection
                    behaviorSection
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }

            Divider()

            toolbar
        }
        .frame(minWidth: 440, idealWidth: 500, minHeight: 360)
        .navigationTitle(draft.isEditingExisting ? "Edit Column" : "New Column")
        .onChange(of: draft.dataType) { newValue in
            guard isPostgres else { return }
            if let match = Self.postgresDataTypes.first(where: { $0.caseInsensitiveCompare(newValue) == .orderedSame }) {
                draft.selectedDataType = match
            } else {
                draft.selectedDataType = nil
            }
        }
    }

    private var generalSection: some View {
        Section {
            TextField("Column Name", text: $draft.name)
            if isPostgres {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Data Type", selection: postgresTypeSelectionBinding) {
                        Text("Custom").tag("")
                        ForEach(Self.postgresDataTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    TextField("Custom Data Type", text: $draft.dataType)
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                TextField("Data Type", text: $draft.dataType)
                    .textFieldStyle(.roundedBorder)
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
            TextField("Default Value", text: $draft.defaultValue)
                .textFieldStyle(.roundedBorder)
            TextField("Generated Expression", text: $draft.generatedExpression)
                .textFieldStyle(.roundedBorder)
        } header: {
            Text("Behavior")
        } footer: {
            Text("Leave optional fields blank to omit them.")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if draft.isEditingExisting {
                Button("Delete Column", role: .destructive) {
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
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(uiColor: .systemGroupedBackground)
        #endif
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
               let match = ColumnEditorSheet.postgresDataTypes.first(where: { $0.caseInsensitiveCompare(model.dataType) == .orderedSame }) {
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

    private static let postgresDataTypes: [String] = {
        let types = [
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
        ]
        return types.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }()
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
        .background(.ultraThinMaterial)
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
