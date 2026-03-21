import SwiftUI
import SQLServerKit

struct MSSQLActivityFileIO: View {
    let io: [SQLServerFileIOStatDelta]
    @Binding var sortOrder: [KeyPathComparator<SQLServerFileIOStatDelta>]
    @Binding var selection: Set<SQLServerFileIOStatDelta.ID>
    var onDoubleClick: (() -> Void)?

    private var sortedIO: [SQLServerFileIOStatDelta] {
        io.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedIO, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Database", value: \.sortableDatabaseName) {
                Text($0.databaseName ?? "DB \($0.databaseId)")
                    .font(TypographyTokens.Table.name)
                    .lineLimit(1)
            }.width(min: 100, ideal: 140)

            TableColumn("File", value: \.sortableFileName) {
                Text($0.fileName ?? "File \($0.fileId)")
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }.width(min: 80, ideal: 120)

            TableColumn("Read", value: \.bytesReadDelta) {
                Text(formatBytes($0.bytesReadDelta))
                    .font(TypographyTokens.Table.numeric)
            }.width(min: 60, ideal: 70)

            TableColumn("Write", value: \.bytesWrittenDelta) {
                Text(formatBytes($0.bytesWrittenDelta))
                    .font(TypographyTokens.Table.numeric)
            }.width(min: 60, ideal: 70)

            TableColumn("Read Ops", value: \.numReadsDelta) {
                Text("\($0.numReadsDelta)")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }.width(min: 55, ideal: 65)

            TableColumn("Write Ops", value: \.numWritesDelta) {
                Text("\($0.numWritesDelta)")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }.width(min: 55, ideal: 65)

            TableColumn("Read Stall", value: \.ioStallReadMsDelta) {
                Text("\($0.ioStallReadMsDelta)ms")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle($0.ioStallReadMsDelta > 100 ? ColorTokens.Status.error : ColorTokens.Text.secondary)
            }.width(min: 60, ideal: 70)

            TableColumn("Write Stall", value: \.ioStallWriteMsDelta) {
                Text("\($0.ioStallWriteMsDelta)ms")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle($0.ioStallWriteMsDelta > 100 ? ColorTokens.Status.error : ColorTokens.Text.secondary)
            }.width(min: 60, ideal: 70)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: SQLServerFileIOStatDelta.ID.self) { _ in
        } primaryAction: { _ in
            onDoubleClick?()
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .binary)
    }
}
