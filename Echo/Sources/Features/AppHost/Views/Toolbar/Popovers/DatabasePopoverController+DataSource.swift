import SwiftUI

#if os(macOS)
import AppKit

extension DatabasePopoverController {

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        rows.indices.contains(row)
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView()
        rowView.selectionHighlightStyle = .regular
        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard rows.indices.contains(row) else { return nil }
        let name = rows[row]
        let identifier = NSUserInterfaceItemIdentifier("databaseCell")
        let cell: NSTableCellView
        if let existing = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = existing
        } else {
            cell = makeDatabaseCell(identifier: identifier)
        }

        configureDatabase(cell: cell, name: name)
        return cell
    }

    func configureDatabase(cell: NSTableCellView, name: String) {
        cell.textField?.stringValue = name
        if let checkmarkView = cell.viewWithTag(1) as? NSImageView {
            let isSelected = environmentState.sessionCoordinator.sessionForConnection(connectionID)?.selectedDatabaseName == name
            checkmarkView.alphaValue = isSelected ? 1 : 0
        }
        if let iconView = cell.viewWithTag(2) as? NSImageView {
            iconView.image = NSImage(systemSymbolName: "cylinder.fill", accessibilityDescription: nil)
            iconView.contentTintColor = .secondaryLabelColor
        }
    }

    func makeDatabaseCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let checkmarkView = NSImageView()
        checkmarkView.tag = 1
        checkmarkView.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        checkmarkView.contentTintColor = .secondaryLabelColor
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.tag = 2
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let textField = NSTextField(labelWithString: "")
        textField.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false
        cell.textField = textField

        let innerStack = NSStackView(views: [checkmarkView, iconView, textField])
        innerStack.orientation = .horizontal
        innerStack.spacing = 6
        innerStack.alignment = .centerY
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(innerStack)

        NSLayoutConstraint.activate([
            innerStack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            innerStack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            innerStack.topAnchor.constraint(equalTo: cell.topAnchor),
            innerStack.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: 12),
            checkmarkView.heightAnchor.constraint(equalToConstant: 12),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16)
        ])

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        selectDatabase(at: tableView.selectedRow)
    }

    func selectDatabase(at index: Int) {
        guard rows.indices.contains(index) else { return }
        let name = rows[index]

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            guard let session = self.environmentState.sessionCoordinator.sessionForConnection(self.connectionID) else { return }
            await self.environmentState.loadSchemaForDatabase(name, connectionSession: session)
            await MainActor.run {
                self.view.window?.performClose(nil)
            }
        }
    }
}
#endif
