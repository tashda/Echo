import SwiftUI
import AppKit

// Column cell helpers are now minimal since we use SwiftUI Table.
// The data type cell helper for non-table contexts is retained.

extension TableStructureEditorView {

    @ViewBuilder
    internal func dataTypeCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        Text(column.dataType)
            .font(TypographyTokens.detail.monospaced())
            .foregroundStyle(ColorTokens.Text.secondary)
    }
}
