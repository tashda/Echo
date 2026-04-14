import SwiftUI

/// Shared column selection list used by PK, UQ, and FK editor sheets.
/// Displays a reorderable list of columns with drag handles and delete buttons,
/// plus an "Add Column" menu at the bottom.
struct ColumnSelectionList: View {

    enum DisplayMode {
        /// Shows column name as read-only text (PK, UQ).
        case text
        /// Shows column name as a picker with available options (FK).
        case picker
    }

    struct Column: Identifiable {
        let id: UUID
        var name: String

        init(id: UUID = UUID(), name: String) {
            self.id = id
            self.name = name
        }
    }

    @Binding var columns: [Column]
    let displayMode: DisplayMode
    let availableColumns: [String]
    let minColumns: Int
    /// For picker mode: returns the options for a given column ID (excluding columns used elsewhere).
    var pickerOptions: ((UUID) -> [String])?

    @State private var hoveredColumnID: UUID?

    var body: some View {
        ForEach(Array(columns.enumerated()), id: \.element.id) { _, column in
            columnRow(for: column)
        }
        .onMove { from, to in
            columns.move(fromOffsets: from, toOffset: to)
        }

        Menu {
            ForEach(addableColumns, id: \.self) { name in
                Button(name) {
                    columns.append(Column(id: UUID(), name: name))
                }
            }
        } label: {
            Label("Add Column", systemImage: "plus")
        }
        .menuStyle(.borderlessButton)
        .disabled(addableColumns.isEmpty)
    }

    private var addableColumns: [String] {
        let used = Set(columns.map(\.name))
        return availableColumns.filter { !used.contains($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    @ViewBuilder
    private func columnRow(for column: Column) -> some View {
        let index = columns.firstIndex(where: { $0.id == column.id })!

        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "line.3.horizontal")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)

            switch displayMode {
            case .text:
                Text(column.name)
                    .font(TypographyTokens.standard)
                    .frame(maxWidth: .infinity, alignment: .leading)

            case .picker:
                let options = pickerOptions?(column.id) ?? addableColumns
                Picker("", selection: $columns[index].name) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()

                Spacer()
            }

            Button(role: .destructive) {
                columns.removeAll { $0.id == column.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(hoveredColumnID == column.id ? ColorTokens.Status.error : ColorTokens.Text.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove column")
            .disabled(columns.count <= minColumns)
            .onHover { isHovered in
                hoveredColumnID = isHovered ? column.id : nil
            }
        }
    }
}
