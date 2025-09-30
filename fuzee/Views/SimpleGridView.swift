import SwiftUI

struct SimpleGridView: View {
    let resultSet: QueryResultSet
    @State private var selection = Set<Int>()
    @State private var columnWidths: [CGFloat] = []

    private let rowHeight: CGFloat = 28
    private let rowNumberWidth: CGFloat = 60
    private let minColumnWidth: CGFloat = 100

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                // Header
                headerRow
                    .background(Color(nsColor: .controlBackgroundColor))

                // Data rows
                ForEach(Array(resultSet.rows.enumerated()), id: \.offset) { index, rowData in
                    dataRow(index: index, data: rowData)
                }
            }
        }
        .onAppear {
            initializeColumnWidths()
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            // Row number header
            Text("#")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: rowNumberWidth, height: 34)
                .background(Color(nsColor: .controlBackgroundColor))

            // Column headers
            ForEach(Array(resultSet.columns.enumerated()), id: \.offset) { index, column in
                Text(column.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: columnWidths[safe: index] ?? minColumnWidth, height: 34, alignment: .leading)
                    .padding(.horizontal, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .overlay(Rectangle().frame(width: 1).foregroundStyle(.separator), alignment: .trailing)
            }
        }
        .overlay(Rectangle().frame(height: 1).foregroundStyle(.separator), alignment: .bottom)
    }

    private func dataRow(index: Int, data: [String?]) -> some View {
        HStack(spacing: 0) {
            // Row number
            Text("\(index + 1)")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: rowNumberWidth, height: rowHeight, alignment: .trailing)
                .padding(.trailing, 8)
                .background(index % 2 == 0 ? Color.clear : Color(nsColor: .controlBackgroundColor).opacity(0.5))

            // Data cells
            ForEach(Array(data.enumerated()), id: \.offset) { columnIndex, cellValue in
                Text(cellValue ?? "NULL")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(cellValue == nil ? .tertiary : .primary)
                    .frame(width: columnWidths[safe: columnIndex] ?? minColumnWidth, height: rowHeight, alignment: .leading)
                    .padding(.horizontal, 8)
                    .background(index % 2 == 0 ? Color.clear : Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .overlay(Rectangle().frame(width: 1).foregroundStyle(.separator.opacity(0.3)), alignment: .trailing)
                    .textSelection(.enabled)
                    .contextMenu {
                        Button("Copy Cell") {
                            copyToClipboard(cellValue ?? "NULL")
                        }
                        Divider()
                        Button("Copy Row") {
                            copyRow(data, includeHeaders: false)
                        }
                        Button("Copy Row with Headers") {
                            copyRow(data, includeHeaders: true)
                        }
                    }
            }
        }
        .overlay(Rectangle().frame(height: 1).foregroundStyle(.separator.opacity(0.3)), alignment: .bottom)
    }

    private func initializeColumnWidths() {
        columnWidths = resultSet.columns.map { _ in minColumnWidth }
    }

    private func copyRow(_ data: [String?], includeHeaders: Bool) {
        var output = ""
        if includeHeaders {
            output = resultSet.columns.map(\.name).joined(separator: "\t") + "\n"
        }
        output += data.map { $0 ?? "NULL" }.joined(separator: "\t")
        copyToClipboard(output)
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}