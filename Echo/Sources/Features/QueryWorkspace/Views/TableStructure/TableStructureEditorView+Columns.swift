import SwiftUI

extension TableStructureEditorView {
    
    internal var columnsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            modernColumnsHeader
            adaptiveColumnsTableUI
        }
        .padding(.vertical, SpacingTokens.xxs2)
    }

    private var modernColumnsHeader: some View {
        HStack(spacing: 12) {
            Label("Columns", systemImage: "tablecells")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 15, weight: .semibold))

            if !selectedColumnIDs.isEmpty {
                Text("(\(selectedColumnIDs.count) selected)")
                    .font(TypographyTokens.caption2)
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
    internal var adaptiveColumnsTableUI: some View {
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
                dataTypeCell(for: column)

                if let description = columnChangeDescription(for: column) {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
#endif
    }

    private var tableHeaderBackgroundColor: Color { ColorTokens.Background.secondary }
    private var tableBackgroundColor: Color { Color(nsColor: .textBackgroundColor) }
    private var tableDividerColor: Color { Color(nsColor: .separatorColor).opacity(0.5) }
    private var tableBorderColor: Color { Color(nsColor: .separatorColor).opacity(0.3) }

    internal func rowBackgroundColor(for index: Int, isSelected: Bool) -> Color {
        if isSelected { return Color.accentColor.opacity(0.15) }
        return index % 2 == 0 ? Color.clear : Color.primary.opacity(0.02)
    }

#if os(macOS)
    private var columnsHeader: some View {
        HStack(spacing: 0) {
            headerCell("NAME", width: ColumnLayout.name, alignment: .leading)
            headerCell("DATA TYPE", width: ColumnLayout.dataType, alignment: .leading)
            headerCell("NULL", width: ColumnLayout.allowNull, alignment: .center)
            headerCell("DEFAULT", width: ColumnLayout.defaultValue, alignment: .trailing)
            headerCell("GENERATED", width: ColumnLayout.generated, alignment: .trailing)
            headerCell("STATUS", width: ColumnLayout.status, alignment: .leading)
            Spacer()
            headerCell("CHANGES", width: nil, alignment: .leading)
        }
        .padding(.horizontal, SpacingTokens.md)
        .frame(height: 32)
        .background(tableHeaderBackgroundColor)
    }

    private func headerCell(_ title: String, width: CGFloat?, alignment: Alignment) -> some View {
        Group {
            if let width = width {
                Text(title)
                    .frame(width: width, alignment: alignment)
            } else {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: alignment)
            }
        }
        .font(TypographyTokens.label.weight(.bold))
        .foregroundStyle(.secondary)
    }

#endif
}
