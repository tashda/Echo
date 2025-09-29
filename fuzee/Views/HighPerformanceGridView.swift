import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif


struct HighPerformanceGridView: View {
    let resultSet: QueryResultSet
    @State private var selectedCells: Set<CellPosition> = []
    @State private var selectedRows: Set<Int> = []
    @State private var textSelectableCell: CellPosition? = nil
    @State private var columnWidths: [CGFloat] = []
    @State private var sortColumn: String?
    @State private var sortAscending = true
    @State private var visibleRows: Range<Int> = 0..<50
    @State private var scrollOffset: CGPoint = .zero

    @EnvironmentObject private var themeManager: ThemeManager

    private let rowHeight: CGFloat = 28
    private let headerHeight: CGFloat = 34
    private let rowNumberWidth: CGFloat = 60
    private let minColumnWidth: CGFloat = 80
    private let maxColumnWidth: CGFloat = 2000

    struct CellPosition: Hashable {
        let row: Int
        let column: Int
    }

    var sortedRows: [(originalIndex: Int, data: [String?])] {
        let enumerated = Array(resultSet.rows.enumerated()).map { (originalIndex: $0.offset, data: $0.element) }

        guard let sortColumn = sortColumn,
              let columnIndex = resultSet.columns.firstIndex(where: { $0.name == sortColumn }) else {
            return enumerated
        }

        return enumerated.sorted { row1, row2 in
            let value1 = row1.data[safe: columnIndex] ?? ""
            let value2 = row2.data[safe: columnIndex] ?? ""

            if let num1 = Double(value1 ?? ""), let num2 = Double(value2 ?? "") {
                return sortAscending ? num1 < num2 : num1 > num2
            }

            return sortAscending ? (value1 ?? "") < (value2 ?? "") : (value1 ?? "") > (value2 ?? "")
        }
    }

    var totalColumnsWidth: CGFloat {
        return columnWidths.reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 0) {
            controlsHeader

            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView([.horizontal, .vertical]) {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            Section {
                                // Render only visible rows for performance
                                ForEach(visibleRows, id: \.self) { displayIndex in
                                    if displayIndex < sortedRows.count {
                                        let rowData = sortedRows[displayIndex]
                                        dataRowView(
                                            originalIndex: rowData.originalIndex,
                                            displayIndex: displayIndex,
                                            rowData: rowData.data,
                                            geometry: geometry
                                        )
                                        .id("row-\(rowData.originalIndex)")
                                        // This is the performance enhancement.
                                        // It flattens the complex row view into a single bitmap for rendering.
                                        .drawingGroup()
                                    }
                                }

                                // Invisible spacer for total height to enable scrolling
                                if sortedRows.count > visibleRows.upperBound {
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(
                                            height: CGFloat(sortedRows.count - visibleRows.upperBound) * rowHeight
                                        )
                                        .onAppear {
                                            loadMoreRows()
                                        }
                                }
                            } header: {
                                stickyHeaderRow(geometry: geometry)
                                    .background(themeManager.backgroundColor)
                            }
                        }
                        .frame(minHeight: geometry.size.height)
                    }
                    .clipped()
                    #if os(macOS)
                    .background(Color(PlatformColor.textBackgroundColor))
                                    #else
                .background(Color(PlatformColor.systemBackground))
                #endif
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                        updateVisibleRows(for: offset, viewHeight: geometry.size.height)
                    }
                }
            }
        }
        .onAppear {
            initializeColumnWidths()
        }
        .onChange(of: resultSet.columns.map(\.name)) { _, _ in
             initializeColumnWidths()
        }
        #if os(macOS)
        .onCommand(#selector(NSText.copy(_:)), perform: {
            copySelection()
        })
        .onCommand(#selector(NSText.selectAll(_:)), perform: {
            selectAllCells()
        })
        #endif
    }

    // MARK: - Helper Views

    @ViewBuilder
    private var controlsHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image("table_list")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(resultSet.rows.count) rows")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !selectedRows.isEmpty {
                    Text("• \(selectedRows.count) rows selected")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                if !selectedCells.isEmpty {
                    Text("• \(selectedCells.count) cells selected")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button("Clear Selection") {
                    clearSelection()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(selectedRows.isEmpty && selectedCells.isEmpty)

                Button("Copy") {
                    copySelection()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(selectedRows.isEmpty && selectedCells.isEmpty)
                .keyboardShortcut("c", modifiers: .command)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(themeManager.backgroundColor)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(.separator), alignment: .bottom)
    }

    @ViewBuilder
    private func stickyHeaderRow(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Row number header
            Text("#")
                .font(.system(.caption, design: .default))
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: rowNumberWidth, height: headerHeight)
                .background(themeManager.backgroundColor)
                .overlay(Rectangle().frame(width: 1).foregroundStyle(.separator), alignment: .trailing)

            ForEach(Array(resultSet.columns.enumerated()), id: \.offset) { columnIndex, column in
                columnHeaderView(column: column, columnIndex: columnIndex)
            }
        }
        // This frame ensures the header has a definite width, matching the data rows.
        .frame(width: totalColumnsWidth + rowNumberWidth, alignment: .leading)
        .background(themeManager.backgroundColor)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(.separator), alignment: .bottom)
    }

    @ViewBuilder
    private func columnHeaderView(column: ColumnInfo, columnIndex: Int) -> some View {
        let columnWidth = columnWidths[safe: columnIndex] ?? minColumnWidth

        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(column.name)
                        .font(.system(.caption, design: .default))
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if column.isPrimaryKey {
                        Image(systemName: "key.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }

                    if sortColumn == column.name {
                        Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }

                    Spacer()
                }

                Text(formatDataType(column))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(width: columnWidth - 6, height: headerHeight, alignment: .leading)

            // Resize handle
            Rectangle()
                .fill(Color.clear)
                .frame(width: 6)
                .contentShape(Rectangle())
                #if os(macOS)
                .cursor(.resizeLeftRight)
                #endif
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            resizeColumn(columnIndex: columnIndex, delta: value.translation.width)
                        }
                )
        }
        .frame(width: columnWidth, height: headerHeight)
        .background(themeManager.backgroundColor)
        .overlay(Rectangle().frame(width: 1).foregroundStyle(.separator), alignment: .trailing)
        .contentShape(Rectangle())
        .onTapGesture {
            handleColumnHeaderClick(columnIndex: columnIndex)
        }
        .contextMenu {
            columnHeaderContextMenu(column: column, columnIndex: columnIndex)
        }
    }

    @ViewBuilder
    private func dataRowView(originalIndex: Int, displayIndex: Int, rowData: [String?], geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Row number
            Text("\(displayIndex + 1)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: rowNumberWidth, height: rowHeight)
                .background(
                    Rectangle()
                        .fill(selectedRows.contains(originalIndex) ? Color.accentColor.opacity(0.2) : Color.clear)
                )
                .overlay(Rectangle().frame(width: 1).foregroundStyle(.separator), alignment: .trailing)
                .contentShape(Rectangle())
                .onTapGesture {
                    handleRowNumberClick(originalIndex)
                }
                .contextMenu {
                    rowContextMenu(originalIndex: originalIndex)
                }

            ForEach(Array(rowData.enumerated()), id: \.offset) { columnIndex, cellData in
                let column = resultSet.columns[safe: columnIndex] ?? ColumnInfo(name: "unknown", dataType: "text")
                let cellPosition = CellPosition(row: originalIndex, column: columnIndex)

                dataCellView(
                    cellData: cellData,
                    column: column,
                    cellPosition: cellPosition,
                    isRowSelected: selectedRows.contains(originalIndex),
                    isCellSelected: selectedCells.contains(cellPosition)
                )
            }
        }
        // This frame ensures the data row has a definite width, matching the header.
        .frame(width: totalColumnsWidth + rowNumberWidth, alignment: .leading)
        .frame(height: rowHeight)
        .background(rowBackground(originalIndex: originalIndex, displayIndex: displayIndex))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(.separator.opacity(0.3)), alignment: .bottom)
    }

    @ViewBuilder
    private func dataCellView(
        cellData: String?,
        column: ColumnInfo,
        cellPosition: CellPosition,
        isRowSelected: Bool,
        isCellSelected: Bool
    ) -> some View {
        let cellWidth = columnWidths[safe: cellPosition.column] ?? minColumnWidth

        Group {
            if let cellValue = cellData, !cellValue.isEmpty {
                formattedCellContent(cellValue, dataType: column.dataType)
            } else {
                Text("NULL")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .if(textSelectableCell == cellPosition) { view in
            view.textSelection(.enabled)
        }
        .frame(width: cellWidth, height: rowHeight, alignment: .leading)
        .padding(.horizontal, 6)
        .background(cellBackground(isRowSelected: isRowSelected, isCellSelected: isCellSelected))
        .overlay(Rectangle().frame(width: 1).foregroundStyle(.separator.opacity(0.3)), alignment: .trailing)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    handleCellDoubleClick(cellPosition, cellData: cellData)
                }
        )
        .simultaneousGesture(
            TapGesture(count: 1)
                .onEnded {
                    handleCellClick(cellPosition)
                }
        )
        .contextMenu {
            cellContextMenu(cellPosition: cellPosition, cellData: cellData)
        }
    }

    // MARK: - Performance Methods

    private func updateVisibleRows(for offset: CGPoint, viewHeight: CGFloat) {
        let startRow = max(0, Int(offset.y / rowHeight) - 10)
        let endRow = min(sortedRows.count, Int((offset.y + viewHeight) / rowHeight) + 10)

        let newVisibleRows = startRow..<endRow
        if newVisibleRows != visibleRows {
            visibleRows = newVisibleRows
        }
    }

    private func loadMoreRows() {
        let batchSize = 50
        let newUpperBound = min(sortedRows.count, visibleRows.upperBound + batchSize)
        visibleRows = visibleRows.lowerBound..<newUpperBound
    }

    // MARK: - Helper Methods

    private func initializeColumnWidths() {
        columnWidths = resultSet.columns.enumerated().map { index, column in
            calculateOptimalColumnWidth(columnIndex: index, column: column)
        }
    }

    private func calculateOptimalColumnWidth(columnIndex: Int, column: ColumnInfo) -> CGFloat {
        let headerFont = PlatformFont.systemFont(ofSize: 11, weight: .semibold)
        let dataFont = PlatformFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let headerWidth = column.name.widthOfString(usingFont: headerFont) + 60

        // Clarified logic to help with type inference
        let dataWidths = resultSet.rows.prefix(50).compactMap { row -> CGFloat? in
            guard let optionalCellData = row[safe: columnIndex] else { return nil } // Check for out-of-bounds index
            let cellText = optionalCellData ?? "NULL" // Handle SQL NULL values
            return cellText.widthOfString(usingFont: dataFont) + 20.0
        }
        let maxDataWidth = dataWidths.max() ?? 80.0

        return max(minColumnWidth, min(maxColumnWidth, max(headerWidth, maxDataWidth)))
    }

    private func resizeColumn(columnIndex: Int, delta: CGFloat) {
        guard columnIndex < columnWidths.count else { return }
        let newWidth = max(minColumnWidth, min(maxColumnWidth, columnWidths[columnIndex] + delta))
        columnWidths[columnIndex] = newWidth
    }

    private func clearSelection() {
        selectedCells.removeAll()
        selectedRows.removeAll()
        textSelectableCell = nil
    }

    private func selectAllCells() {
        selectedCells = Set(
            (0..<resultSet.rows.count).flatMap { row in
                (0..<resultSet.columns.count).map { col in
                    CellPosition(row: row, column: col)
                }
            }
        )
        selectedRows.removeAll()
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

    private func copySelection() {
        var output = ""
        
        if !selectedRows.isEmpty {
            let sortedSelectedRows = selectedRows.sorted()
            let headers = resultSet.columns.map { $0.name }.joined(separator: "\t")
            output += headers + "\n"
            
            for rowIndex in sortedSelectedRows {
                if let rowData = resultSet.rows[safe: rowIndex] {
                    let line = rowData.map { $0 ?? "NULL" }.joined(separator: "\t")
                    output += line + "\n"
                }
            }
        }
        else if !selectedCells.isEmpty {
            let values = selectedCells.sorted(by: { $0.row < $1.row || ($0.row == $1.row && $0.column < $1.column) }).compactMap { cellPos -> String? in
                guard let rowData = resultSet.rows[safe: cellPos.row],
                      let cellValue = rowData[safe: cellPos.column] else { return nil }
                return cellValue ?? "NULL"
            }
            output = values.joined(separator: "\n")
        }
        
        if !output.isEmpty {
            copyToClipboard(output)
        }
    }

    private func handleCellClick(_ cellPosition: CellPosition) {
        textSelectableCell = nil
        selectedRows.removeAll()
        
        if selectedCells == [cellPosition] {
            selectedCells.removeAll()
        } else {
            selectedCells = [cellPosition]
        }
    }

    private func handleCellDoubleClick(_ cellPosition: CellPosition, cellData: String?) {
        selectedRows.removeAll()
        selectedCells = [cellPosition]
        textSelectableCell = cellPosition
    }

    private func handleRowNumberClick(_ originalIndex: Int) {
        textSelectableCell = nil
        selectedCells.removeAll()

        if selectedRows.contains(originalIndex) {
            selectedRows.remove(originalIndex)
        } else {
            selectedRows = [originalIndex]
        }
    }

    private func handleColumnHeaderClick(columnIndex: Int) {
        guard let column = resultSet.columns[safe: columnIndex] else { return }
        handleColumnSort(column.name)
    }

    // Context menu methods
    @ViewBuilder
    private func columnHeaderContextMenu(column: ColumnInfo, columnIndex: Int) -> some View {
        Button("Copy Column") {
            copyColumn(columnIndex: columnIndex)
        }

        Divider()

        Button("Sort Ascending") {
            handleColumnSort(column.name, ascending: true)
        }
        Button("Sort Descending") {
            handleColumnSort(column.name, ascending: false)
        }
    }

    @ViewBuilder
    private func cellContextMenu(cellPosition: CellPosition, cellData: String?) -> some View {
        Button("Copy Cell") {
            copySingleCell(cellPosition: cellPosition, cellData: cellData)
        }
        Divider()
        Button("Copy Row") {
            copyRow(cellPosition.row, includeHeaders: false)
        }
        Button("Copy Row with Headers") {
            copyRow(cellPosition.row, includeHeaders: true)
        }
    }

    @ViewBuilder
    private func rowContextMenu(originalIndex: Int) -> some View {
        Button("Copy Row") {
            copyRow(originalIndex, includeHeaders: false)
        }
        Button("Copy Row with Headers") {
            copyRow(originalIndex, includeHeaders: true)
        }
    }

    // Formatting and display methods
    @ViewBuilder
    private func formattedCellContent(_ value: String, dataType: String) -> some View {
        let type = dataType.lowercased()
        let sanitizedValue = sanitizeString(value)

        if type.contains("int") || type.contains("numeric") || type.contains("decimal") || type.contains("float") || type.contains("double") {
            Text(sanitizedValue)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.blue)
        } else if type.contains("bool") {
            HStack(spacing: 4) {
                Image(systemName: sanitizedValue.lowercased() == "true" || sanitizedValue == "1" ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(sanitizedValue.lowercased() == "true" || sanitizedValue == "1" ? .green : .red)
                Text(sanitizedValue)
                    .font(.system(.callout, design: .monospaced))
            }
        } else if type.contains("time") || type.contains("timestamp") {
            Text(formatTimeValue(sanitizedValue))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.purple)
        } else {
            Text(sanitizedValue.isEmpty ? "<invalid data>" : sanitizedValue)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(sanitizedValue.isEmpty ? .red : .primary)
                .lineLimit(1)
        }
    }

    private func formatTimeValue(_ value: String) -> String {
        let sanitizedValue = sanitizeString(value)
        let cleanValue = sanitizedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanValue.isEmpty ? "<invalid data>" : cleanValue
    }

    private func sanitizeString(_ input: String) -> String {
        let filtered = input.unicodeScalars.compactMap { scalar in
            if scalar.isASCII {
                let value = scalar.value
                if value == 32 || value == 9 || value == 10 || (value >= 32 && value <= 126) {
                    return scalar
                }
                return nil
            } else {
                return scalar.properties.isGraphemeBase || scalar.properties.isGraphemeExtend ? scalar : nil
            }
        }
        return String(String.UnicodeScalarView(filtered))
    }

    private func formatDataType(_ column: ColumnInfo) -> String {
        var type = column.dataType.uppercased()
        if let maxLength = column.maxLength {
            type += "(\(maxLength))"
        }
        if !column.isNullable {
            type += " NOT NULL"
        }
        return type
    }

    private func rowBackground(originalIndex: Int, displayIndex: Int) -> Color {
        if selectedRows.contains(originalIndex) {
            return Color.accentColor.opacity(0.15)
        } else if themeManager.showAlternateRowShading && displayIndex % 2 == 1 {
            return Color.primary.opacity(0.02)
        } else {
            return Color.clear
        }
    }

    private func cellBackground(isRowSelected: Bool, isCellSelected: Bool) -> Color {
        if isCellSelected {
            return Color.orange.opacity(0.3)
        } else if isRowSelected {
            return Color.clear
        } else {
            return Color.clear
        }
    }

    private func handleColumnSort(_ columnName: String, ascending: Bool? = nil) {
        if let ascending = ascending {
            sortColumn = columnName
            sortAscending = ascending
        } else {
            if sortColumn == columnName {
                sortAscending.toggle()
            } else {
                sortColumn = columnName
                sortAscending = true
            }
        }
    }

    private func copyColumn(columnIndex: Int) {
        guard columnIndex < resultSet.columns.count else { return }
        
        let values = resultSet.rows.map { row in
            row[safe: columnIndex]??.description ?? "NULL"
        }
        
        let output = values.joined(separator: "\n")
        copyToClipboard(output)
    }
    
    private func copySingleCell(cellPosition: CellPosition, cellData: String?) {
        copyToClipboard(cellData ?? "")
    }

    private func copyRow(_ index: Int, includeHeaders: Bool) {
        guard let rowData = resultSet.rows[safe: index] else { return }
        var output = ""

        if includeHeaders {
            let headers = resultSet.columns.map { $0.name }.joined(separator: "\t")
            output += headers + "\n"
        }

        let line = rowData.map { $0 ?? "NULL" }.joined(separator: "\t")
        output += line

        copyToClipboard(output)
    }
}

// Scroll offset preference key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {}
}

// Extensions
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    #if os(macOS)
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { isHovering in
            if isHovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
    #endif
}

extension String {
    func widthOfString(usingFont font: PlatformFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: fontAttributes)
        return size.width
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
