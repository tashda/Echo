import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Native macOS Table Implementation

@available(macOS 13.0, *)
extension TableStructureEditorView {
    
    @ViewBuilder
    var nativeColumnsTable: some View {
        // Always show the table, use viewModel.columns directly if cached is empty
        let columnsToShow = cachedVisibleColumns.isEmpty ? viewModel.columns.filter { !$0.isDeleted } : cachedVisibleColumns
        
        if columnsToShow.isEmpty {
            VStack(spacing: 8) {
                fastEmptyState
                Text("DEBUG: cachedVisibleColumns.count = \(cachedVisibleColumns.count)")
                    .font(.caption)
                    .foregroundStyle(.red)
                Text("DEBUG: viewModel.columns.count = \(viewModel.columns.count)")
                    .font(.caption)
                    .foregroundStyle(.red)
                Text("DEBUG: columnsToShow.count = \(columnsToShow.count)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } else {
            // Ultra-fast native table with minimal overhead
            Table(columnsToShow, selection: $selectedColumnIDs) {
                TableColumn("Name") { column in
                    HStack(spacing: 6) {
                        Text(column.name)
                            .font(.system(size: 13, weight: .medium))
                        if column.isNew {
                            Circle()
                                .fill(.blue)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                .width(min: 180, ideal: 220)
                
                TableColumn("Data Type") { column in
                    Text(column.dataType.uppercased())
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .width(min: 120, ideal: 160)
                
                TableColumn("Nullable") { column in
                    Image(systemName: column.isNullable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(column.isNullable ? .green : .red)
                        .font(.system(size: 12))
                }
                .width(min: 80, ideal: 90)
                
                TableColumn("Default") { column in
                    Text(column.defaultValue?.isEmpty == false ? column.defaultValue! : "—")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .width(min: 120, ideal: 180)
                
                TableColumn("Generated") { column in
                    Text(column.generatedExpression?.isEmpty == false ? column.generatedExpression! : "—")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .width(min: 120, ideal: 200)
                
                TableColumn("Status") { column in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(column.isNew ? .blue : column.isDirty ? .orange : .green)
                            .frame(width: 6, height: 6)
                        Text(column.isNew ? "New" : column.isDirty ? "Modified" : "Synced")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(column.isNew || column.isDirty ? .primary : .secondary)
                    }
                }
                .width(min: 80, ideal: 120)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .contextMenu(forSelectionType: UUID.self) { selection in
                if !selection.isEmpty {
                    let targets = selection.compactMap { id in
                        columnsToShow.first(where: { $0.id == id })
                    }
                    nativeContextMenu(for: targets)
                }
            }
            .onTapGesture(count: 2) {
                if let firstSelected = selectedColumnIDs.first,
                   let column = columnsToShow.first(where: { $0.id == firstSelected }) {
                    presentColumnEditor(for: column)
                }
            }
        }
    }
    
    private var fastEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tablecells")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            
            Text("No columns yet")
                .font(.system(size: 14, weight: .medium))
            
            Button("Add Column") {
                presentNewColumn()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    

    
    private var modernEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tablecells")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 4) {
                Text("No columns yet")
                    .font(.system(size: 16, weight: .medium))
                
                Text("Add your first column to get started")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            
            Button(action: presentNewColumn) {
                Label("Add Column", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
    


    // MARK: - Context Menu
    
    @ViewBuilder
    private func nativeContextMenu(for targets: [TableStructureEditorViewModel.ColumnModel]) -> some View {
        if let first = targets.first, targets.count == 1 {
            Button("Edit Column") { 
                presentColumnEditor(for: first) 
            }
        }
        
        if targets.count > 1 {
            Menu("Edit Columns") {
                Button("Edit Data Type") { 
                    presentBulkEditor(mode: .dataType, columns: targets) 
                }
                Button("Edit Default Value") { 
                    presentBulkEditor(mode: .defaultValue, columns: targets) 
                }
                Button("Edit Generated Expression") { 
                    presentBulkEditor(mode: .generatedExpression, columns: targets) 
                }
            }
        }
        
        if !targets.isEmpty {
            Divider()
            let title = targets.count == 1 ? "Remove Column" : "Remove Columns"
            Button(title, role: .destructive) { 
                removeColumns(targets) 
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func presentNewColumn() {
        let model = viewModel.addColumn()
        activeColumnEditor = ColumnEditorPresentation(columnID: model.id, isNew: true)
    }
}

// MARK: - Fast Fallback Table for older macOS versions

extension TableStructureEditorView {
    @ViewBuilder
    var adaptiveColumnsTable: some View {
        if #available(macOS 13.0, *) {
            nativeColumnsTable
        } else {
            fastLegacyTable
        }
    }
    
    // Ultra-fast legacy table for macOS < 13.0
    @ViewBuilder
    private var fastLegacyTable: some View {
        // Always show the table, use viewModel.columns directly if cached is empty
        let columnsToShow = cachedVisibleColumns.isEmpty ? viewModel.columns.filter { !$0.isDeleted } : cachedVisibleColumns
        
        if columnsToShow.isEmpty {
            fastEmptyState
        } else {
            VStack(spacing: 0) {
                // Simple header
                HStack(spacing: 0) {
                    Text("Name").frame(width: 220, alignment: .leading)
                    Text("Data Type").frame(width: 160, alignment: .leading)
                    Text("Nullable").frame(width: 90, alignment: .center)
                    Text("Default").frame(width: 180, alignment: .trailing)
                    Text("Status").frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                
                Divider()
                
                // Fast rows with minimal overhead
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(columnsToShow.enumerated()), id: \.element.id) { index, column in
                            fastColumnRow(column: column, index: index)
                        }
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
    }
    
    private func fastColumnRow(column: TableStructureEditorViewModel.ColumnModel, index: Int) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(column.name)
                    .font(.system(size: 13, weight: .medium))
                if column.isNew {
                    Circle().fill(.blue).frame(width: 6, height: 6)
                }
            }
            .frame(width: 220, alignment: .leading)
            
            Text(column.dataType.uppercased())
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 160, alignment: .leading)
            
            Image(systemName: column.isNullable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(column.isNullable ? .green : .red)
                .font(.system(size: 12))
                .frame(width: 90, alignment: .center)
            
            Text(column.defaultValue?.isEmpty == false ? column.defaultValue! : "—")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 180, alignment: .trailing)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(column.isNew ? .blue : column.isDirty ? .orange : .green)
                    .frame(width: 6, height: 6)
                Text(column.isNew ? "New" : column.isDirty ? "Modified" : "Synced")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(column.isNew || column.isDirty ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(index.isMultiple(of: 2) ? Color.clear : Color(nsColor: .controlAlternatingRowBackgroundColors[1]))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            presentColumnEditor(for: column)
        }
        .contextMenu {
            Button("Edit Column") { presentColumnEditor(for: column) }
            Button("Remove Column", role: .destructive) { viewModel.removeColumn(column) }
        }
    }
}
