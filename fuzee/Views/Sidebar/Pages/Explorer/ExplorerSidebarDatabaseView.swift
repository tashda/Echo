import SwiftUI

struct DatabaseStructureView: View {
    let structure: DatabaseStructure
    @State private var expandedItems = Set<String>()
    @State private var selectedItemID: String? // Added for selection management

    private let baseIndent: CGFloat = 16 // Consistent indentation unit

    var body: some View {
        List {
            ForEach(structure.databases, id: \.name) { database in
                Section {
                    if !database.tables.isEmpty {
                        DisclosureGroup(
                            isExpanded: isExpandedBinding(for: "tables-\(database.name)"),
                            content: {
                                ForEach(database.tables) { table in
                                    // Replaced TableOrViewRow with SchemaObjectRow
                                    SchemaObjectRow(
                                        object: table,
                                        expandedItems: $expandedItems,
                                        selectedItemID: $selectedItemID,
                                        leadingPaddingAmount: baseIndent * 2 // Indent for tables/views
                                    )
                                }
                            },
                            label: {
                                groupLabel(title: "Tables", systemImage: "tablecells.fill", count: database.tables.count)
                            }
                        )
                    }

                    if !database.views.isEmpty {
                        DisclosureGroup(
                            isExpanded: isExpandedBinding(for: "views-\(database.name)"),
                            content: {
                                ForEach(database.views) { view in
                                    // Replaced TableOrViewRow with SchemaObjectRow
                                    SchemaObjectRow(
                                        object: view,
                                        expandedItems: $expandedItems,
                                        selectedItemID: $selectedItemID,
                                        leadingPaddingAmount: baseIndent * 2 // Indent for tables/views
                                    )
                                }
                            },
                            label: {
                                groupLabel(title: "Views", systemImage: "eye.fill", count: database.views.count)
                            }
                        )
                    }
                } header: {
                    Text(database.name)
                        .font(.headline)
                        .padding(.top, 10)
                }
            }
        }
        .listStyle(.sidebar)
        .onAppear {
            // Pre-expand the top-level groups by default
            for db in structure.databases {
                expandedItems.insert("tables-\(db.name)")
                expandedItems.insert("views-\(db.name)")
            }
        }
    }

    private func isExpandedBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: { expandedItems.contains(key) },
            set: { isExpanded in
                if isExpanded {
                    expandedItems.insert(key)
                } else {
                    expandedItems.remove(key)
                }
            }
        )
    }

    private func groupLabel(title: String, systemImage: String, count: Int) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(title)
            Spacer()
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.05), in: .capsule)
        }
        .font(.callout)
    }
}


struct SelectableRowContainer<Content: View>: View {
    let id: String
    @Binding var selectedItemID: String?
    let leadingPadding: CGFloat // Explicit leading padding for this row
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .leading) { // Use ZStack to layer background and content
            // The highlight background, spanning full width
            if selectedItemID == id {
                RoundedRectangle(cornerRadius: 6, style: .continuous) // Adjust corner radius
                    .fill(Color.accentColor.opacity(0.15)) // System-like light highlight
                    .padding(.horizontal, 6) // Give some horizontal padding to the highlight shape to float it
            }

            // The actual content, which needs its own padding
            content
                .padding(.vertical, 4) // Vertical padding for content within the row
                .padding(.leading, leadingPadding) // Apply leading padding to the content itself
        }
        .frame(maxWidth: .infinity, alignment: .leading) // Ensure the tappable area spans horizontally
        .contentShape(Rectangle()) // Make the full row tappable
        .onTapGesture {
            selectedItemID = id
        }
    }
}

struct SchemaObjectRow: View {
    let object: SchemaObjectInfo
    @Binding var expandedItems: Set<String>
    @Binding var selectedItemID: String? // Added
    let leadingPaddingAmount: CGFloat // Added

    private let baseIndent: CGFloat = 16 // Consistent indentation unit

    private func expansionBinding(for key: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { expandedItems.contains(key) },
            set: { isExpanded in
                if isExpanded {
                    expandedItems.insert(key)
                } else {
                    expandedItems.remove(key)
                }
            }
        )
    }
    
    var body: some View {
        SelectableRowContainer(id: "object:\(object.id)", selectedItemID: $selectedItemID, leadingPadding: leadingPaddingAmount) {
            DisclosureGroup(
                isExpanded: expansionBinding(for: "object:\(object.id)")
            ) {
                ForEach(object.columns) { column in
                    ColumnRow(column: column, selectedItemID: $selectedItemID, parentObjectID: object.id, leadingPaddingAmount: leadingPaddingAmount + baseIndent)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: object.type == .table ? "tablecells" : "eye")
                        .foregroundStyle(object.type == .table ? .blue : .green)
                    Text(object.fullName)
                        .font(.callout)
                }
            }
        }
    }
}

struct ColumnRow: View {
    let column: ColumnInfo
    @Binding var selectedItemID: String? // Added
    let parentObjectID: String // Changed from UUID to String
    let leadingPaddingAmount: CGFloat // Added

    var body: some View {
        SelectableRowContainer(id: "column:\(parentObjectID).\(column.name)", selectedItemID: $selectedItemID, leadingPadding: leadingPaddingAmount) {
            HStack(spacing: 4) {
                Image(systemName: "key.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .opacity(column.isPrimaryKey ? 1 : 0)

                Text(column.name)
                    .font(.callout)
                
                Spacer()
                
                Text(column.dataType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}


