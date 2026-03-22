#if os(macOS)
import AppKit
import SwiftUI

extension QueryResultsTableView.Coordinator: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let tableView else { return }
        menu.removeAllItems()

        if menu === headerMenu {
            let clickedColumn = menuColumnIndex ?? tableView.clickedColumn
            guard clickedColumn >= 0 else {
                menuColumnIndex = nil
                return
            }
            menuColumnIndex = clickedColumn

            guard let dataIndex = menuColumnIndex,
                  dataIndex < queryState.displayedColumns.count else { return }

            selectColumn(at: dataIndex, in: tableView)

            let ascendingItem = NSMenuItem(title: "Sort Ascending", action: #selector(sortAscending), keyEquivalent: "")
            ascendingItem.target = self
            if let sort = parent.activeSort,
               sort.column == queryState.displayedColumns[dataIndex].name,
               sort.ascending {
                ascendingItem.state = .on
            }
            menu.addItem(ascendingItem)

            let descendingItem = NSMenuItem(title: "Sort Descending", action: #selector(sortDescending), keyEquivalent: "")
            descendingItem.target = self
            if let sort = parent.activeSort,
               sort.column == queryState.displayedColumns[dataIndex].name,
               !sort.ascending {
                descendingItem.state = .on
            }
            menu.addItem(descendingItem)

            menu.addItem(.separator())

            let copyColumnItem = NSMenuItem(title: "Copy Column", action: #selector(copyColumnPlain), keyEquivalent: "c")
            copyColumnItem.target = self
            copyColumnItem.isEnabled = hasCopyableSelection()
            copyColumnItem.keyEquivalentModifierMask = [.command]
            copyColumnItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
            menu.addItem(copyColumnItem)

            let copyColumnWithHeadersItem = NSMenuItem(title: "Copy Column with Headers", action: #selector(copyColumnWithHeaders), keyEquivalent: "c")
            copyColumnWithHeadersItem.target = self
            copyColumnWithHeadersItem.isEnabled = hasCopyableSelection()
            copyColumnWithHeadersItem.keyEquivalentModifierMask = [.command, .shift]
            copyColumnWithHeadersItem.image = NSImage(systemSymbolName: "tablecells", accessibilityDescription: nil)
            menu.addItem(copyColumnWithHeadersItem)

            menu.addItem(.separator())
            menu.addItem(buildCopyAsSubmenuItem())
            menu.addItem(buildSaveAsSubmenuItem())

            menu.addItem(.separator())

            let hideItem = NSMenuItem(title: "Hide Column", action: #selector(hideSelectedColumn), keyEquivalent: "")
            hideItem.target = self
            hideItem.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: nil)
            menu.addItem(hideItem)

            if hasHiddenColumns {
                let showAllItem = NSMenuItem(
                    title: "Show All Columns (\(hiddenColumnCount) hidden)",
                    action: #selector(showAllHiddenColumns),
                    keyEquivalent: ""
                )
                showAllItem.target = self
                showAllItem.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)
                menu.addItem(showAllItem)
            }
        } else if menu === cellMenu {
            updateCellMenu(menu, tableView: tableView)
        }
    }

    @objc func sortAscending() {
        guard let dataIndex = menuColumnIndex else { return }
        parent.onSort(dataIndex, .ascending)
    }

    @objc func sortDescending() {
        guard let dataIndex = menuColumnIndex else { return }
        parent.onSort(dataIndex, .descending)
    }

    @objc func copyColumnPlain() {
        copySelection(includeHeaders: false)
    }

    @objc func copyColumnWithHeaders() {
        copySelection(includeHeaders: true)
    }

    func updateCellMenu(_ menu: NSMenu, tableView: NSTableView) {
        menuColumnIndex = nil
        ensureSelectionForContextMenu(tableView: tableView)

        let hasSelection = hasCopyableSelection()

        let copyItem = NSMenuItem(title: "Copy", action: #selector(copySelectionPlain), keyEquivalent: "c")
        copyItem.target = self
        copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        copyItem.isEnabled = hasSelection
        copyItem.keyEquivalentModifierMask = [.command]
        menu.addItem(copyItem)

        let copyHeadersItem = NSMenuItem(title: "Copy with Headers", action: #selector(copySelectionWithHeaders), keyEquivalent: "c")
        copyHeadersItem.target = self
        copyHeadersItem.image = NSImage(systemSymbolName: "tablecells", accessibilityDescription: nil)
        copyHeadersItem.isEnabled = hasSelection
        copyHeadersItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(copyHeadersItem)

        menu.addItem(.separator())
        menu.addItem(buildCopyAsSubmenuItem())
        menu.addItem(buildSaveAsSubmenuItem())
    }

    func prepareHeaderContextMenu(at column: Int?) {
        if let column, column >= 0 {
            menuColumnIndex = column
        } else {
            menuColumnIndex = nil
        }
    }

    func prepareRowContextMenu(at row: Int) -> NSMenu? {
        guard let tableView else { return nil }
        beginRowSelection(at: row)
        isDraggingRowSelection = false
        selectionFocus = QueryResultsTableView.SelectedCell(
            row: row,
            column: max(queryState.displayedColumns.count - 1, 0)
        )
        contextMenuCell = nil
        tableView.deselectAll(nil)
        tableView.selectionHighlightStyle = .none
        return cellMenu
    }

    func ensureSelectionForContextMenu(tableView: NSTableView) {
        let cell = consumeContextMenuCell()
            ?? resolvedCell(forRow: tableView.clickedRow, column: tableView.clickedColumn, tableView: tableView)
        guard let cell else { return }

        if let region = selectionRegion, region.contains(cell) {
            tableView.deselectAll(nil)
            tableView.selectionHighlightStyle = .none
            return
        }

        setSelectionRegion(SelectedRegion(start: cell, end: cell), tableView: tableView)
        notifyClearColumnHighlight()
    }

    func hasCopyableSelection() -> Bool {
        guard let tableView else { return false }

        if let selectionRegion {
            let columnCount = queryState.displayedColumns.count
            let rowCount = tableView.numberOfRows
            guard columnCount > 0, rowCount > 0 else { return false }

            let lowerRow = max(selectionRegion.normalizedRowRange.lowerBound, 0)
            let upperRow = min(selectionRegion.normalizedRowRange.upperBound, rowCount - 1)
            guard upperRow >= lowerRow else { return false }

            let lowerColumn = max(selectionRegion.normalizedColumnRange.lowerBound, 0)
            let upperColumn = min(selectionRegion.normalizedColumnRange.upperBound, columnCount - 1)
            guard upperColumn >= lowerColumn else { return false }

            return true
        }

        return !tableView.selectedRowIndexes.isEmpty
    }

    @objc func copySelectionPlain() {
        copySelection(includeHeaders: false)
    }

    @objc func copySelectionWithHeaders() {
        copySelection(includeHeaders: true)
    }

    func performMenuCopy(in tableView: NSTableView) -> Bool {
        guard self.tableView === tableView else { return false }
        copySelection(includeHeaders: false)
        return true
    }

    func consumeContextMenuCell() -> QueryResultsTableView.SelectedCell? {
        defer { contextMenuCell = nil }
        return contextMenuCell
    }

    // MARK: - Copy As Submenu

    private func buildCopyAsSubmenuItem() -> NSMenuItem {
        let submenuItem = NSMenuItem(title: "Copy As", action: nil, keyEquivalent: "")
        submenuItem.image = NSImage(systemSymbolName: "square.on.square", accessibilityDescription: nil)
        let submenu = NSMenu(title: "Copy As")
        let hasSelection = hasCopyableSelection()
        for format in ResultExportFormat.copyFormats {
            let action: Selector
            switch format {
            case .tsv: action = #selector(copyAsTSV)
            case .csv: action = #selector(copyAsCSV)
            case .json: action = #selector(copyAsJSON)
            case .sqlInsert: action = #selector(copyAsSQLInsert)
            case .markdown: action = #selector(copyAsMarkdown)
            case .xlsx: continue
            }
            let item = NSMenuItem(title: format.menuTitle, action: action, keyEquivalent: "")
            item.target = self
            item.isEnabled = hasSelection
            submenu.addItem(item)
        }
        submenuItem.submenu = submenu
        return submenuItem
    }

    @objc func hideSelectedColumn() {
        guard let dataIndex = menuColumnIndex else { return }
        hideColumn(at: dataIndex)
    }

    @objc func showAllHiddenColumns() {
        showAllColumns()
    }

    @objc func copyAsTSV() { copySelectionAs(format: .tsv) }
    @objc func copyAsCSV() { copySelectionAs(format: .csv) }
    @objc func copyAsJSON() { copySelectionAs(format: .json) }
    @objc func copyAsSQLInsert() { copySelectionAs(format: .sqlInsert) }
    @objc func copyAsMarkdown() { copySelectionAs(format: .markdown) }

    // MARK: - Save As Submenu

    private func buildSaveAsSubmenuItem() -> NSMenuItem {
        let submenuItem = NSMenuItem(title: "Save As", action: nil, keyEquivalent: "")
        submenuItem.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: nil)
        let submenu = NSMenu(title: "Save As")
        let hasSelection = hasCopyableSelection()
        for format in ResultExportFormat.allCases {
            let action: Selector
            switch format {
            case .tsv: action = #selector(saveAsTSV)
            case .csv: action = #selector(saveAsCSV)
            case .json: action = #selector(saveAsJSON)
            case .sqlInsert: action = #selector(saveAsSQLInsert)
            case .markdown: action = #selector(saveAsMarkdown)
            case .xlsx: action = #selector(saveAsXLSX)
            }
            let item = NSMenuItem(title: format.menuTitle, action: action, keyEquivalent: "")
            item.target = self
            item.isEnabled = hasSelection
            submenu.addItem(item)
        }
        submenuItem.submenu = submenu
        return submenuItem
    }

    @objc func saveAsTSV() { saveSelectionAs(format: .tsv) }
    @objc func saveAsCSV() { saveSelectionAs(format: .csv) }
    @objc func saveAsJSON() { saveSelectionAs(format: .json) }
    @objc func saveAsSQLInsert() { saveSelectionAs(format: .sqlInsert) }
    @objc func saveAsMarkdown() { saveSelectionAs(format: .markdown) }
    @objc func saveAsXLSX() { saveSelectionAs(format: .xlsx) }

    func saveSelectionAs(format: ResultExportFormat) {
        guard let data = gatherSelectionData() else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "results.\(format.fileExtension)"
        panel.allowedContentTypes = format.contentTypes
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        if format.isBinaryFormat {
            Task {
                do {
                    try await XLSXExportWriter.write(headers: data.headers, rows: data.rows, to: url)
                } catch {
                    _ = await MainActor.run { NSAlert(error: error).runModal() }
                }
            }
        } else {
            let content = ResultTableExportFormatter.format(format, headers: data.headers, rows: data.rows)
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}
#endif
