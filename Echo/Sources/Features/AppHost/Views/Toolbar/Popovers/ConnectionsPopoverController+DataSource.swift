import SwiftUI

#if os(macOS)
import AppKit

extension ConnectionsPopoverController {

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        rows.indices.contains(row)
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = HoverTableRowView()
        rowView.selectionHighlightStyle = .regular
        if let hoverTableView = tableView as? HoverTableView {
            rowView.isHovered = hoverTableView.hoveredRow == row
        }
        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard rows.indices.contains(row) else { return nil }
        let connection = rows[row]
        let identifier = NSUserInterfaceItemIdentifier("connectionCell")
        let cell: NSTableCellView
        if let existing = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = existing
        } else {
            cell = makeConnectionCell(identifier: identifier)
        }

        configure(cell: cell, with: connection)
        return cell
    }

    func configure(cell: NSTableCellView, with connection: SavedConnection) {
        cell.textField?.stringValue = displayName(for: connection)
        cell.textField?.toolTip = "\(connection.username)@\(connection.host)"
        if let checkmarkView = cell.viewWithTag(1) as? NSImageView {
            let isSelected = connection.id == connectionStore.selectedConnectionID
            checkmarkView.alphaValue = isSelected ? 1 : 0
        }
        if let iconView = cell.viewWithTag(2) as? NSImageView {
            if let image = NSImage(named: connection.databaseType.iconName) {
                iconView.image = image
                iconView.contentTintColor = nil
            } else {
                iconView.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)
                iconView.contentTintColor = .secondaryLabelColor
            }
        }
    }

    func makeConnectionCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
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
        textField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        textField.alignment = .left
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false
        cell.textField = textField
        cell.imageView = iconView

        cell.addSubview(checkmarkView)
        cell.addSubview(iconView)
        cell.addSubview(textField)

        NSLayoutConstraint.activate([
            checkmarkView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            checkmarkView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: 10),
            checkmarkView.heightAnchor.constraint(equalToConstant: 10),
            iconView.leadingAnchor.constraint(equalTo: checkmarkView.trailingAnchor, constant: 6),
            iconView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),
            textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        return cell
    }

    func displayName(for connection: SavedConnection) -> String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? connection.host : trimmed
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        selectConnection(at: tableView.selectedRow)
    }

    func selectConnection(at index: Int) {
        guard rows.indices.contains(index) else { return }
        let connection = rows[index]
        Task {
            await environmentState.connect(to: connection)
        }
        view.window?.performClose(nil)
    }
}
#endif
