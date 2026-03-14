import SwiftUI

extension DatabaseObjectRow {
    var columnsList: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            ForEach(object.columns, id: \.name) { (column: ColumnInfo) in
                DatabaseObjectColumnRow(
                    column: column,
                    isHovered: hoveredColumnID == column.name,
                    onCopyName: { copyColumnName(column) },
                    onRename: { openStructureEditor(for: column) },
                    onDrop: { openStructureEditor(for: column, preferDrop: true) }
                )
#if os(macOS)
                .onHover { hovering in
                    var transaction = Transaction()
                    transaction.animation = nil
                    withTransaction(transaction) {
                        if hovering {
                            hoveredColumnID = column.name
                        } else if hoveredColumnID == column.name {
                            hoveredColumnID = nil
                        }
                    }
                }
#endif
            }
        }
        .onDisappear {
            hoveredColumnID = nil
        }
    }

    internal func copyColumnName(_ column: ColumnInfo) {
        let name = column.name
#if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(name, forType: .string)
#else
        UIPasteboard.general.string = name
#endif
    }

    internal func openStructureEditor(for column: ColumnInfo, preferDrop: Bool = false) {
        Task { @MainActor in
            guard let session = environmentState.sessionCoordinator.sessionForConnection(connection.id) else { return }
            environmentState.openStructureTab(for: session, object: object, focus: .columns)
        }
    }
}
