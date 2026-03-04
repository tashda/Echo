import SwiftUI

#if os(macOS)
import AppKit

@MainActor
final class ConnectionsPopoverController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSSearchFieldDelegate {
    private let connectionStore: ConnectionStore
    private let environmentState: EnvironmentState
    private var rows: [SavedConnection] = []
    private var all: [SavedConnection] = []

    private let searchField = NSSearchField(frame: .zero)
    private let tableView = HoverTableView(frame: .zero)
    private let scrollView = NSScrollView(frame: .zero)

    init(connectionStore: ConnectionStore, environmentState: EnvironmentState) {
        self.connectionStore = connectionStore
        self.environmentState = environmentState
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = NSView()
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.clear.cgColor
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        reloadConnections()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.acceptsMouseMovedEvents = true
    }

    private func configureUI() {
        preferredContentSize = NSSize(width: 260, height: 320)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])

        searchField.placeholderString = "Filter"
        searchField.controlSize = .small
        searchField.font = NSFont.systemFont(ofSize: 12)
        searchField.focusRingType = .default
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(searchField)

        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.documentView = tableView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(scrollView)

        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 22
        tableView.rowSizeStyle = .small
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.allowsEmptySelection = true
        tableView.focusRingType = .none
        tableView.selectionHighlightStyle = .regular
        tableView.backgroundColor = .clear
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.gridStyleMask = []
        if #available(macOS 11, *) {
            tableView.style = .plain
        }
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("connection"))
        column.width = 240
        tableView.addTableColumn(column)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(separator)

        let actionsStack = NSStackView()
        actionsStack.orientation = .vertical
        actionsStack.spacing = 2
        actionsStack.alignment = .leading
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        actionsStack.addArrangedSubview(makeActionButton(title: "New Connection…", action: #selector(openNewConnection)))
        actionsStack.addArrangedSubview(makeActionButton(title: "Manage Connections…", action: #selector(openManageConnections)))
        stack.addArrangedSubview(actionsStack)

        NSLayoutConstraint.activate([
            searchField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            separator.widthAnchor.constraint(equalTo: stack.widthAnchor),
            actionsStack.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func reloadConnections() {
        all = connectionStore.connections.sorted { lhs, rhs in
            displayName(for: lhs).localizedCaseInsensitiveCompare(displayName(for: rhs)) == .orderedAscending
        }
        applyFilter(searchField.stringValue)
    }

    private func applyFilter(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let filter: (SavedConnection) -> Bool = { connection in
            guard !trimmed.isEmpty else { return true }
            return connection.connectionName.localizedCaseInsensitiveContains(trimmed) ||
                connection.host.localizedCaseInsensitiveContains(trimmed)
        }

        rows = all.filter(filter)
        tableView.reloadData()
        updateSelection()
    }

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

    private func configure(cell: NSTableCellView, with connection: SavedConnection) {
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

    private func makeConnectionCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
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

    private func displayName(for connection: SavedConnection) -> String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? connection.host : trimmed
    }

    private func updateSelection() {
        guard let selectedID = connectionStore.selectedConnectionID,
              let index = rows.firstIndex(where: { $0.id == selectedID }) else {
            tableView.deselectAll(nil)
            return
        }
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }

    private func makeActionButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.bezelStyle = .inline
        button.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        button.alignment = .left
        button.contentTintColor = .labelColor
        button.focusRingType = .none
        return button
    }

    @objc private func openNewConnection() {
        ManageConnectionsWindowController.shared.present()
    }

    @objc private func openManageConnections() {
        ManageConnectionsWindowController.shared.present()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        selectConnection(at: tableView.selectedRow)
    }

    private func selectConnection(at index: Int) {
        guard rows.indices.contains(index) else { return }
        let connection = rows[index]
        Task {
            await environmentState.connect(to: connection)
        }
        view.window?.performClose(nil)
    }

    func controlTextDidChange(_ obj: Notification) {
        applyFilter(searchField.stringValue)
    }
}

private final class HoverTableView: NSTableView {
    private var trackingArea: NSTrackingArea?
    private(set) var hoveredRow: Int = -1

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let point = convert(event.locationInWindow, from: nil)
        setHoveredRow(row(at: point))
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        setHoveredRow(-1)
    }

    private func setHoveredRow(_ row: Int) {
        if row == hoveredRow { return }
        let previousRow = hoveredRow
        hoveredRow = row
        if previousRow >= 0,
           let rowView = rowView(atRow: previousRow, makeIfNecessary: false) as? HoverTableRowView {
            rowView.isHovered = false
        }
        if hoveredRow >= 0,
           let rowView = rowView(atRow: hoveredRow, makeIfNecessary: false) as? HoverTableRowView {
            rowView.isHovered = true
        }
    }
}

private final class HoverTableRowView: NSTableRowView {
    var isHovered = false {
        didSet { needsDisplay = true }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        if isHovered && !isSelected {
            NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
            dirtyRect.fill()
            return
        }
        super.drawBackground(in: dirtyRect)
    }
}

@MainActor
final class DatabasePopoverController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSSearchFieldDelegate {
    private let environmentState: EnvironmentState
    private let connectionID: UUID

    private var all: [String] = []
    private var rows: [String] = []
    private var loadTask: Task<Void, Never>?

    private let searchField = NSSearchField(frame: .zero)
    private let tableView = NSTableView(frame: .zero)
    private let scrollView = NSScrollView(frame: .zero)
    private let progressIndicator = NSProgressIndicator()

    init(environmentState: EnvironmentState, connectionID: UUID) {
        self.environmentState = environmentState
        self.connectionID = connectionID
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        loadTask?.cancel()
    }

    override func loadView() {
        let effectView = NSVisualEffectView()
        effectView.material = .popover
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        view = effectView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        loadDatabases()
    }

    private func configureUI() {
        preferredContentSize = NSSize(width: 280, height: 320)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 10, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        searchField.placeholderString = "Filter"
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = self
        stack.addArrangedSubview(searchField)

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        stack.addArrangedSubview(progressIndicator)

        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.documentView = tableView
        stack.addArrangedSubview(scrollView)

        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 24
        tableView.selectionHighlightStyle = .sourceList
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.focusRingType = .none
        tableView.allowsEmptySelection = true
        tableView.backgroundColor = .clear
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.gridStyleMask = []
        if #available(macOS 11, *) {
            tableView.style = .sourceList
        }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("database"))
        column.width = 240
        tableView.addTableColumn(column)
    }

    private func loadDatabases() {
        progressIndicator.startAnimation(nil)
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            guard let session = self.environmentState.sessionManager.sessionForConnection(self.connectionID) else {
                await MainActor.run { self.progressIndicator.stopAnimation(nil) }
                return
            }

            if let structure = session.databaseStructure {
                await MainActor.run { self.handle(structure: structure) }
                return
            }

            await self.environmentState.refreshDatabaseStructure(for: session.id, scope: .full)
            guard let refreshed = session.databaseStructure else {
                await MainActor.run { self.progressIndicator.stopAnimation(nil) }
                return
            }

            await MainActor.run { self.handle(structure: refreshed) }
        }
    }

    private func handle(structure: DatabaseStructure) {
        progressIndicator.stopAnimation(nil)
        all = structure.databases.map(\.name).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        applyFilter(searchField.stringValue)
    }

    private func applyFilter(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let filter: (String) -> Bool = { name in
            guard !trimmed.isEmpty else { return true }
            return name.localizedCaseInsensitiveContains(trimmed)
        }

        rows = all.filter(filter)
        tableView.reloadData()
        updateSelection()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        rows.indices.contains(row)
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView()
        rowView.selectionHighlightStyle = .sourceList
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

    private func configureDatabase(cell: NSTableCellView, name: String) {
        cell.textField?.stringValue = name
        if let checkmarkView = cell.viewWithTag(1) as? NSImageView {
            let isSelected = environmentState.sessionManager.sessionForConnection(connectionID)?.selectedDatabaseName == name
            checkmarkView.alphaValue = isSelected ? 1 : 0
        }
        if let iconView = cell.viewWithTag(2) as? NSImageView {
            iconView.image = NSImage(systemSymbolName: "cylinder.fill", accessibilityDescription: nil)
            iconView.contentTintColor = .secondaryLabelColor
        }
    }

    private func makeDatabaseCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
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

    private func updateSelection() {
        guard let selectedName = environmentState.sessionManager.sessionForConnection(connectionID)?.selectedDatabaseName,
              let index = rows.firstIndex(of: selectedName) else {
            tableView.deselectAll(nil)
            return
        }
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        selectDatabase(at: tableView.selectedRow)
    }

    private func selectDatabase(at index: Int) {
        guard rows.indices.contains(index) else { return }
        let name = rows[index]

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            guard let session = self.environmentState.sessionManager.sessionForConnection(self.connectionID) else { return }
            await self.environmentState.loadSchemaForDatabase(name, connectionSession: session)
            await MainActor.run {
                self.view.window?.performClose(nil)
            }
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        applyFilter(searchField.stringValue)
    }
}
#endif
