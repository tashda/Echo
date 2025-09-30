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
    @State private var cachedSortedRows: [(originalIndex: Int, data: [String?])] = []
    @State private var cachedRowsFingerprint: Int = 0
    @State private var cachedSortColumn: String?
    @State private var cachedSortAscending: Bool = true
    @State private var anchorCell: CellPosition?
    @State private var rowSelectionAnchor: Int?

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

    private var rowsFingerprint: Int {
        fingerprint(for: resultSet.rows)
    }

    var totalColumnsWidth: CGFloat {
        return columnWidths.reduce(0, +)
    }

    var body: some View {
        let rows = cachedSortedRows

        return VStack(spacing: 0) {
            controlsHeader

            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView([.horizontal, .vertical]) {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            Section {
                                // Render only visible rows for performance
                                ForEach(visibleRows, id: \.self) { displayIndex in
                                    if displayIndex < rows.count {
                                        let rowData = rows[displayIndex]
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
                                if rows.count > visibleRows.upperBound {
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(
                                            height: CGFloat(rows.count - visibleRows.upperBound) * rowHeight
                                        )
                                        .onAppear {
                                            loadMoreRows(totalRows: rows.count)
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
                    .coordinateSpace(name: "HighPerformanceGridScroll")
                    .background(
                        GeometryReader { proxy in
                            let origin = proxy.frame(in: .named("HighPerformanceGridScroll")).origin
                            let offset = CGPoint(x: -origin.x, y: -origin.y)
                            Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: offset)
                        }
                    )
                    #if os(macOS)
                    .background(Color(PlatformColor.textBackgroundColor))
                                    #else
                .background(Color(PlatformColor.systemBackground))
                #endif
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                        updateVisibleRows(for: offset, viewHeight: geometry.size.height, totalRows: rows.count)
                    }
                }
            }
        }
        .onAppear {
            initializeColumnWidths()
            recomputeSortedRows(resetSelection: true)
            resetVisibleRows(totalRows: cachedSortedRows.count, resetToTop: true)
        }
        .onChange(of: resultSet.columns.map(\.name)) { _, _ in
            initializeColumnWidths()
            recomputeSortedRows(resetSelection: true)
            resetVisibleRows(totalRows: cachedSortedRows.count, resetToTop: true)
        }
        .onChange(of: rowsFingerprint) { _, _ in
            recomputeSortedRows(resetSelection: true)
            resetVisibleRows(totalRows: cachedSortedRows.count, resetToTop: true)
        }
        .onChange(of: sortColumn) { _, _ in
            recomputeSortedRows(resetSelection: false)
            resetVisibleRows(totalRows: cachedSortedRows.count, resetToTop: false)
        }
        .onChange(of: sortAscending) { _, _ in
            recomputeSortedRows(resetSelection: false)
            resetVisibleRows(totalRows: cachedSortedRows.count, resetToTop: false)
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

    private func updateVisibleRows(for offset: CGPoint, viewHeight: CGFloat, totalRows: Int) {
        let sanitizedTotal = max(totalRows, 0)
        guard sanitizedTotal > 0 else {
            if visibleRows != 0..<0 {
                visibleRows = 0..<0
            }
            return
        }

        let proposedStart = max(0, Int(offset.y / rowHeight) - 10)
        let maxStart = max(0, sanitizedTotal - 1)
        let startRow = min(proposedStart, maxStart)

        let proposedEnd = max(startRow, Int((offset.y + viewHeight) / rowHeight) + 10)
        let clampedEnd = min(sanitizedTotal, proposedEnd)
        let endRow = max(startRow, clampedEnd)

        let newVisibleRows = startRow..<endRow
        if newVisibleRows != visibleRows {
            visibleRows = newVisibleRows
        }
    }

    private func loadMoreRows(totalRows: Int) {
        let sanitizedTotal = max(totalRows, 0)
        guard sanitizedTotal > 0 else {
            visibleRows = 0..<0
            return
        }

        let batchSize = 50
        let clampedLower = min(visibleRows.lowerBound, max(0, sanitizedTotal - 1))
        let proposedUpper = max(clampedLower, visibleRows.upperBound + batchSize)
        let newUpperBound = min(sanitizedTotal, proposedUpper)
        visibleRows = clampedLower..<newUpperBound
    }

    // MARK: - Helper Methods

    private func initializeColumnWidths() {
        columnWidths = resultSet.columns.enumerated().map { index, column in
            calculateOptimalColumnWidth(columnIndex: index, column: column)
        }
    }

    private func recomputeSortedRows(resetSelection: Bool) {
        let fingerprint = rowsFingerprint
        if !resetSelection,
           cachedRowsFingerprint == fingerprint,
           cachedSortColumn == sortColumn,
           cachedSortAscending == sortAscending {
            return
        }

        let enumerated = Array(resultSet.rows.enumerated()).map { (originalIndex: $0.offset, data: $0.element) }

        let sortedRows: [(originalIndex: Int, data: [String?])]
        if let sortColumn,
           let columnIndex = resultSet.columns.firstIndex(where: { $0.name == sortColumn }) {
            sortedRows = enumerated.sorted { lhs, rhs in
                let lhsValue = lhs.data[safe: columnIndex] ?? ""
                let rhsValue = rhs.data[safe: columnIndex] ?? ""

                if let lhsNumber = Double(lhsValue ?? ""), let rhsNumber = Double(rhsValue ?? "") {
                    return sortAscending ? lhsNumber < rhsNumber : lhsNumber > rhsNumber
                }

                return sortAscending ? (lhsValue ?? "") < (rhsValue ?? "") : (lhsValue ?? "") > (rhsValue ?? "")
            }
        } else {
            sortedRows = enumerated
        }

        cachedSortedRows = sortedRows
        cachedRowsFingerprint = fingerprint
        cachedSortColumn = sortColumn
        cachedSortAscending = sortAscending

        if resetSelection {
            selectedRows = Set(selectedRows.filter { $0 < resultSet.rows.count })

            let filteredCells = selectedCells.filter { cell in
                cell.row < resultSet.rows.count && cell.column < resultSet.columns.count
            }
            selectedCells = Set(filteredCells)

            if let focusCell = textSelectableCell, !selectedCells.contains(focusCell) {
                textSelectableCell = nil
            }

            if let anchor = anchorCell,
               (anchor.row >= resultSet.rows.count || anchor.column >= resultSet.columns.count) {
                anchorCell = nil
            }

            if let anchorRow = rowSelectionAnchor,
               anchorRow >= resultSet.rows.count {
                rowSelectionAnchor = nil
            }
        }
    }

    private func resetVisibleRows(totalRows: Int, resetToTop: Bool) {
        guard totalRows > 0 else {
            visibleRows = 0..<0
            return
        }

        let desiredCount = min(totalRows, max(visibleRows.count, 50))
        if resetToTop {
            visibleRows = 0..<desiredCount
        } else {
            let lowerBound = min(visibleRows.lowerBound, max(0, totalRows - desiredCount))
            visibleRows = lowerBound..<min(totalRows, lowerBound + desiredCount)
        }
    }

    private func fingerprint(for rows: [[String?]]) -> Int {
        var hasher = Hasher()
        hasher.combine(rows.count)
        for row in rows.prefix(10) {
            hasher.combine(row.count)
            for value in row.prefix(4) {
                hasher.combine(value ?? "")
            }
        }
        return hasher.finalize()
    }

    private func generateCellSelection(from start: CellPosition, to end: CellPosition) -> Set<CellPosition> {
        let minRow = min(start.row, end.row)
        let maxRow = max(start.row, end.row)
        let minCol = min(start.column, end.column)
        let maxCol = max(start.column, end.column)

        var selection: Set<CellPosition> = []
        for row in minRow...maxRow where row < resultSet.rows.count {
            for column in minCol...maxCol where column < resultSet.columns.count {
                selection.insert(CellPosition(row: row, column: column))
            }
        }
        return selection
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
        anchorCell = nil
        rowSelectionAnchor = nil
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
            let headers = resultSet.columns.map { $0.name }.joined(separator: "\t")
            output += headers + "\n"
            
            for row in cachedSortedRows where selectedRows.contains(row.originalIndex) {
                let line = row.data.map { $0 ?? "NULL" }.joined(separator: "\t")
                output += line + "\n"
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
        #if os(macOS)
        let modifiers = NSApp.currentEvent?.modifierFlags ?? []
        if modifiers.contains(.shift) {
            let anchor = anchorCell ?? cellPosition
            selectedCells = generateCellSelection(from: anchor, to: cellPosition)
            selectedRows.removeAll()
            textSelectableCell = nil
            anchorCell = anchor
            rowSelectionAnchor = nil
            return
        } else if modifiers.contains(.command) {
            selectedRows.removeAll()
            textSelectableCell = nil
            if selectedCells.contains(cellPosition) {
                selectedCells.remove(cellPosition)
                if selectedCells.isEmpty {
                    anchorCell = nil
                }
            } else {
                selectedCells.insert(cellPosition)
                anchorCell = cellPosition
            }
            rowSelectionAnchor = nil
            return
        }
        #endif

        textSelectableCell = nil
        selectedRows.removeAll()
        rowSelectionAnchor = nil

        if selectedCells == [cellPosition] {
            selectedCells.removeAll()
            anchorCell = nil
        } else {
            selectedCells = [cellPosition]
            anchorCell = cellPosition
        }
    }

    private func handleCellDoubleClick(_ cellPosition: CellPosition, cellData: String?) {
        selectedRows.removeAll()
        selectedCells = [cellPosition]
        textSelectableCell = cellPosition
        anchorCell = cellPosition
        rowSelectionAnchor = nil
    }

    private func handleRowNumberClick(_ originalIndex: Int) {
        textSelectableCell = nil
        selectedCells.removeAll()
        anchorCell = nil

        #if os(macOS)
        let modifiers = NSApp.currentEvent?.modifierFlags ?? []
        if modifiers.contains(.shift) {
            let anchor = rowSelectionAnchor ?? originalIndex
            let range = min(anchor, originalIndex)...max(anchor, originalIndex)
            selectedRows = Set(range)
            rowSelectionAnchor = anchor
            return
        } else if modifiers.contains(.command) {
            if selectedRows.contains(originalIndex) {
                selectedRows.remove(originalIndex)
            } else {
                selectedRows.insert(originalIndex)
            }
            rowSelectionAnchor = originalIndex
            return
        }
        #endif

        if selectedRows == [originalIndex] {
            selectedRows.removeAll()
            rowSelectionAnchor = nil
        } else {
            selectedRows = [originalIndex]
            rowSelectionAnchor = originalIndex
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
        let rowData: [String?]
        if let sortedRow = cachedSortedRows[safe: index] {
            rowData = sortedRow.data
        } else if let originalRow = resultSet.rows[safe: index] {
            rowData = originalRow
        } else {
            return
        }
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
