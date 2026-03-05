import SwiftUI

extension ClipboardHistoryRow {
    var infoPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: entry.source.iconName)
                    .font(TypographyTokens.displayLarge.weight(.semibold))
                    .foregroundStyle(entry.source.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.source.caption)
                        .font(.headline)
                    Text(entry.timestampDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(entry.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if entry.metadata.hasDetails {
                metadataSection
            } else {
                Divider()
                    .opacity(0.15)
            }

            if let grid = parsedGrid {
                gridPreview(grid)
            } else {
                ScrollView {
                    Text(entry.content)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }

            Divider()

            Button {
                clipboardHistory.copyEntry(entry)
                showInfo = false
            } label: {
                Label("Copy Data", systemImage: "doc.on.doc")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func gridPreview(_ grid: ParsedGrid) -> some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(spacing: 0) {
                HStack(spacing: 1) {
                    ForEach(grid.headers.indices, id: \.self) { index in
                        gridCell(text: grid.headers[index], isHeader: true)
                    }
                }
                .background(Color.primary.opacity(0.08))

                ForEach(Array(grid.rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 1) {
                        ForEach(0..<grid.headers.count, id: \.self) { columnIndex in
                            let value = columnIndex < row.count ? row[columnIndex] : ""
                            gridCell(text: value, isHeader: false)
                        }
                    }
                    .background(rowIndex.isMultiple(of: 2) ? Color.primary.opacity(0.03) : Color.clear)
                }
            }
            .padding(1)
        }
        .frame(minHeight: 180)
    }

    func gridCell(text: String, isHeader: Bool) -> some View {
        Text(text.isEmpty ? "--" : text)
            .font(isHeader ? .subheadline.weight(.semibold) : .system(.body, design: .monospaced))
            .foregroundStyle(isHeader ? Color.primary : Color.primary)
            .padding(.vertical, SpacingTokens.xxs2)
            .padding(.horizontal, SpacingTokens.xs2)
            .frame(minWidth: 80, alignment: .leading)
            .background(Color.primary.opacity(isHeader ? 0.08 : 0.02))
    }

    var parsedGrid: ParsedGrid? {
        guard case .resultGrid(let includeHeaders) = entry.source else { return nil }

        let lines = entry.content
            .components(separatedBy: CharacterSet.newlines)
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        let rows = lines.map { $0.components(separatedBy: "\t") }
        guard let firstRow = rows.first else { return nil }

        if includeHeaders {
            let headers = firstRow
            let remaining = Array(rows.dropFirst().prefix(50))
            return ParsedGrid(headers: headers, rows: remaining)
        } else {
            let headers = firstRow.indices.map { "Column \($0 + 1)" }
            let limitedRows = Array(rows.prefix(50))
            return ParsedGrid(headers: headers, rows: limitedRows)
        }
    }

    struct ParsedGrid {
        var headers: [String]
        var rows: [[String]]
    }
}
