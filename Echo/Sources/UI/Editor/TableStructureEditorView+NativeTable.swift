import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Native macOS Table Implementation

@available(macOS 13.0, *)
extension TableStructureEditorView {
    
    @ViewBuilder
    var nativeColumnsTable: some View {
        let columns = viewModel.columns.filter { !$0.isDeleted }
        if columns.isEmpty {
            modernEmptyState
        } else {
            Table(columns, selection: $selectedColumnIDs) {
                // Name Column
                TableColumn("Name") { column in
                    HStack(spacing: 8) {
                        Text(column.name)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                        
                        if column.isNew {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundStyle(.blue)
                        } else if column.isDirty {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .width(min: 180, ideal: 220, max: 300)
                
                // Data Type Column
                TableColumn("Data Type") { column in
                    if let binding = columnBinding(for: column.id) {
                        HStack(spacing: 4) {
                            TextField("Data Type", text: Binding(
                                get: { binding.wrappedValue.dataType },
                                set: { binding.wrappedValue.dataType = $0 }
                            ))
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            
                            Menu {
                                ForEach(postgresDataTypeOptions.prefix(10), id: \.self) { option in
                                    Button(option) { 
                                        binding.wrappedValue.dataType = option 
                                    }
                                }
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .menuStyle(.borderlessButton)
                        }
                    } else {
                        Text(column.dataType)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .width(min: 120, ideal: 160, max: 200)
                
                // Allow Null Column
                TableColumn("Allow Null") { column in
                    if let binding = columnBinding(for: column.id) {
                        Toggle("", isOn: binding.isNullable)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    } else {
                        Image(systemName: column.isNullable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(column.isNullable ? .green : .red)
                    }
                }
                .width(min: 80, ideal: 90, max: 100)
                
                // Default Value Column
                TableColumn("Default") { column in
                    if let binding = columnBinding(for: column.id) {
                        TextField("Default", text: Binding(
                            get: { binding.wrappedValue.defaultValue ?? "" },
                            set: { newValue in
                                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                binding.wrappedValue.defaultValue = trimmed.isEmpty ? nil : trimmed
                            }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    } else {
                        Text(column.defaultValue ?? "—")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .width(min: 120, ideal: 180, max: 250)
                
                // Status Column
                TableColumn("Status") { column in
                    let metadata = columnStatusMetadata(for: column)
                    Label(metadata.title, systemImage: metadata.systemImage)
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(metadata.tint)
                        .font(.system(size: 11))
                }
                .width(min: 80, ideal: 120, max: 150)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .contextMenu(forSelectionType: TableStructureEditorViewModel.ColumnModel.ID.self) { selection in
                if selection.isEmpty {
                    Button("Add Column") {
                        presentNewColumn()
                    }
                } else {
                    let targets = selection.compactMap { id in
                        columns.first(where: { $0.id == id })
                    }
                    nativeContextMenu(for: targets)
                }
            }
            .onKeyPress(.return) {
                if let firstSelected = selectedColumnIDs.first,
                   let column = columns.first(where: { $0.id == firstSelected }) {
                    presentColumnEditor(for: column)
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.delete) {
                let targets = selectedColumnIDs.compactMap { id in
                    columns.first(where: { $0.id == id })
                }
                if !targets.isEmpty {
                    removeColumns(targets)
                    return .handled
                }
                return .ignored
            }
        }
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

// MARK: - Fallback for older macOS versions

extension TableStructureEditorView {
    @ViewBuilder
    var adaptiveColumnsTable: some View {
        if #available(macOS 13.0, *) {
            nativeColumnsTable
        } else {
            columnsTable
        }
    }
}
