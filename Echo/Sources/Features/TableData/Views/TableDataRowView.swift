import SwiftUI

struct TableDataRowView: View {
    let rowIndex: Int
    let row: [String?]
    let columns: [TableDataColumn]
    let isEditMode: Bool
    let pendingEdits: [CellEdit]
    let onEditCell: (Int, String?) -> Void
    let onDeleteRow: () -> Void
    let canEdit: Bool

    private let columnMinWidth: CGFloat = 120
    private let rowNumberWidth: CGFloat = 50

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            // Row number
            Text("\(rowIndex + 1)")
                .font(TypographyTokens.detail.monospacedDigit())
                .foregroundStyle(ColorTokens.Text.tertiary)
                .frame(width: rowNumberWidth, alignment: .center)

            if isEditMode {
                deleteButton
            }

            ForEach(Array(columns.enumerated()), id: \.offset) { colIndex, column in
                cellView(colIndex: colIndex, column: column)
            }

            Spacer(minLength: SpacingTokens.none)
        }
        .padding(.vertical, SpacingTokens.xxs2)
        .background(rowIndex % 2 == 0 ? Color.clear : ColorTokens.Background.secondary.opacity(0.3))
    }

    @ViewBuilder
    private func cellView(colIndex: Int, column: TableDataColumn) -> some View {
        let value = colIndex < row.count ? row[colIndex] : nil
        let isEdited = pendingEdits.contains { $0.rowIndex == rowIndex && $0.columnIndex == colIndex }

        if isEditMode && canEdit {
            editableCell(colIndex: colIndex, value: value, isEdited: isEdited)
        } else {
            readOnlyCell(value: value, isEdited: isEdited)
        }
    }

    private func editableCell(colIndex: Int, value: String?, isEdited: Bool) -> some View {
        let binding = Binding<String>(
            get: { value ?? "" },
            set: { newValue in
                onEditCell(colIndex, newValue.isEmpty ? nil : newValue)
            }
        )

        return TextField("", text: binding, prompt: Text("NULL"))
            .font(TypographyTokens.detail.monospaced())
            .textFieldStyle(.plain)
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxs2)
            .frame(minWidth: columnMinWidth, alignment: .leading)
            .background(isEdited ? ColorTokens.Status.warning.opacity(0.1) : Color.clear)
            .border(isEdited ? ColorTokens.Status.warning.opacity(0.3) : Color.clear, width: 1)
    }

    private func readOnlyCell(value: String?, isEdited: Bool) -> some View {
        Group {
            if let value {
                Text(value)
                    .font(TypographyTokens.detail.monospaced())
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)
            } else {
                Text("NULL")
                    .font(TypographyTokens.detail.monospaced().italic())
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(minWidth: columnMinWidth, alignment: .leading)
        .background(isEdited ? ColorTokens.Status.warning.opacity(0.1) : Color.clear)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            onDeleteRow()
        } label: {
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(ColorTokens.Status.error)
        }
        .buttonStyle(.plain)
        .frame(width: 32)
        .disabled(!canEdit)
    }
}
