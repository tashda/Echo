import SwiftUI

#if os(macOS)
import AppKit

@MainActor
final class ConnectionsPopoverController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSSearchFieldDelegate {
    private enum Row {
        case section(String)
        case connection(SavedConnection)
    }

    private let appModel: AppModel
    private var rows: [Row] = []
    private var recent: [SavedConnection] = []
    private var all: [SavedConnection] = []

    private let searchField = NSSearchField(frame: .zero)
    private let tableView = NSTableView(frame: .zero)
    private let scrollView = NSScrollView(frame: .zero)

    init(appModel: AppModel) {
        self.appModel = appModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        reloadConnections()
    }

    private func configureUI() {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 320).isActive = true
        view.heightAnchor.constraint(equalToConstant: 420).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let titleLabel = NSTextField(labelWithString: "Connections")
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(titleLabel)

        searchField.placeholderString = "Filter connections"
        searchField.delegate = self
        stack.addArrangedSubview(searchField)

        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(scrollView)

        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 30
        tableView.intercellSpacing = NSSize(width: 0, height: 6)
        tableView.allowsEmptySelection = false
        tableView.focusRingType = .none
        tableView.selectionHighlightStyle = .regular

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("connection"))
        column.width = 280
        tableView.addTableColumn(column)
    }

    private func reloadConnections() {
        all = appModel.connections.sorted { $0.connectionName < $1.connectionName }
        recent = appModel.connections.filter { conn in
            appModel.recentConnections.contains { $0.connectionID == conn.id }
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

        let filteredRecent = recent.filter(filter)
        let filteredAll = all.filter(filter)

        var assembled: [Row] = []
        if !filteredRecent.isEmpty {
            assembled.append(.section("Recents"))
            assembled.append(contentsOf: filteredRecent.map { .connection($0) })
        }
        if !filteredAll.isEmpty {
            assembled.append(.section("All"))
            assembled.append(contentsOf: filteredAll.map { .connection($0) })
        }
        rows = assembled
        tableView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        guard rows.indices.contains(row) else { return false }
        if case .section = rows[row] { return true }
        return false
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard rows.indices.contains(row) else { return false }
        if case .section = rows[row] { return false }
        return true
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard rows.indices.contains(row) else { return nil }
        switch rows[row] {
        case .section(let title):
            let id = NSUserInterfaceItemIdentifier("section")
            let label: NSTextField
            if let existing = tableView.makeView(withIdentifier: id, owner: self) as? NSTextField {
                label = existing
            } else {
                label = NSTextField(labelWithString: "")
                label.identifier = id
                label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
                label.textColor = .secondaryLabelColor
            }
            label.stringValue = title.uppercased()
            return label
        case .connection(let connection):
            let identifier = NSUserInterfaceItemIdentifier("connectionCell")
            if let existing = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
                configure(cell: existing, with: connection)
                return existing
            }
            let cell = NSTableCellView()
            cell.identifier = identifier
            cell.textField = NSTextField(labelWithString: "")
            cell.textField?.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            cell.textField?.translatesAutoresizingMaskIntoConstraints = false

            let iconView = NSImageView(image: NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil) ?? NSImage())
            iconView.contentTintColor = .secondaryLabelColor
            iconView.translatesAutoresizingMaskIntoConstraints = false

            let innerStack = NSStackView(views: [iconView, cell.textField!])
            innerStack.orientation = .horizontal
            innerStack.spacing = 8
            innerStack.alignment = .centerY
            innerStack.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(innerStack)

            NSLayoutConstraint.activate([
                innerStack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                innerStack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                innerStack.topAnchor.constraint(equalTo: cell.topAnchor),
                innerStack.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 16),
                iconView.heightAnchor.constraint(equalToConstant: 16)
            ])

            configure(cell: cell, with: connection)
            return cell
        }
    }

    private func configure(cell: NSTableCellView, with connection: SavedConnection) {
        cell.textField?.stringValue = connection.connectionName
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        selectConnection(at: tableView.selectedRow)
    }

    private func selectConnection(at index: Int) {
        guard rows.indices.contains(index) else { return }
        guard case let .connection(connection) = rows[index] else { return }
        appModel.selectedConnectionID = connection.id
        view.window?.performClose(nil)
    }

    func controlTextDidChange(_ obj: Notification) {
        applyFilter(searchField.stringValue)
    }
}

@MainActor
final class DatabasePopoverController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSSearchFieldDelegate {
    private enum Row {
        case section(String)
        case database(String)
    }

    private let appModel: AppModel
    private let connectionID: UUID

    private var all: [String] = []
    private var recent: [String] = []
    private var rows: [Row] = []
    private var loadTask: Task<Void, Never>?

    private let searchField = NSSearchField(frame: .zero)
    private let tableView = NSTableView(frame: .zero)
    private let scrollView = NSScrollView(frame: .zero)
    private let progressIndicator = NSProgressIndicator()

    init(appModel: AppModel, connectionID: UUID) {
        self.appModel = appModel
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
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        loadDatabases()
    }

    private func configureUI() {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 280).isActive = true
        view.heightAnchor.constraint(equalToConstant: 320).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let titleLabel = NSTextField(labelWithString: "Databases")
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(titleLabel)

        searchField.placeholderString = "Filter databases"
        searchField.delegate = self
        stack.addArrangedSubview(searchField)

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        stack.addArrangedSubview(progressIndicator)

        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView
        stack.addArrangedSubview(scrollView)

        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 28
        tableView.selectionHighlightStyle = .regular
        tableView.intercellSpacing = NSSize(width: 0, height: 6)
        tableView.focusRingType = .none

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("database"))
        column.width = 240
        tableView.addTableColumn(column)
    }

    private func loadDatabases() {
        progressIndicator.startAnimation(nil)
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            guard let session = self.appModel.sessionManager.sessionForConnection(self.connectionID) else {
                await MainActor.run { self.progressIndicator.stopAnimation(nil) }
                return
            }

            if let structure = session.databaseStructure {
                await MainActor.run { self.handle(structure: structure) }
                return
            }

            await self.appModel.refreshDatabaseStructure(for: session.id, scope: .full)
            guard let refreshed = session.databaseStructure else {
                await MainActor.run { self.progressIndicator.stopAnimation(nil) }
                return
            }

            await MainActor.run { self.handle(structure: refreshed) }
        }
    }

    private func handle(structure: DatabaseStructure) {
        progressIndicator.stopAnimation(nil)
        all = structure.databases.map(\.name).sorted()
        // Basic recents: keep currently selected database first if present.
        if let session = appModel.sessionManager.sessionForConnection(connectionID),
           let selected = session.selectedDatabaseName {
            recent = all.filter { $0 == selected }
        }
        applyFilter(searchField.stringValue)
    }

    private func applyFilter(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let filter: (String) -> Bool = { name in
            guard !trimmed.isEmpty else { return true }
            return name.localizedCaseInsensitiveContains(trimmed)
        }

        let filteredRecent = recent.filter(filter)
        let filteredAll = all.filter(filter)

        var assembled: [Row] = []
        if !filteredRecent.isEmpty {
            assembled.append(.section("Recents"))
            assembled.append(contentsOf: filteredRecent.map { .database($0) })
        }
        if !filteredAll.isEmpty {
            assembled.append(.section("All"))
            assembled.append(contentsOf: filteredAll.map { .database($0) })
        }
        rows = assembled
        tableView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        guard rows.indices.contains(row) else { return false }
        if case .section = rows[row] { return true }
        return false
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard rows.indices.contains(row) else { return false }
        if case .section = rows[row] { return false }
        return true
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard rows.indices.contains(row) else { return nil }
        switch rows[row] {
        case .section(let title):
            let id = NSUserInterfaceItemIdentifier("section")
            let label: NSTextField
            if let existing = tableView.makeView(withIdentifier: id, owner: self) as? NSTextField {
                label = existing
            } else {
                label = NSTextField(labelWithString: "")
                label.identifier = id
                label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
                label.textColor = .secondaryLabelColor
            }
            label.stringValue = title.uppercased()
            return label
        case .database(let name):
            let identifier = NSUserInterfaceItemIdentifier("databaseCell")
            if let existing = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
                configureDatabase(cell: existing, name: name)
                return existing
            }

            let cell = NSTableCellView()
            cell.identifier = identifier
            cell.textField = NSTextField(labelWithString: "")
            cell.textField?.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            cell.textField?.translatesAutoresizingMaskIntoConstraints = false

            let iconView = NSImageView(image: NSImage(systemSymbolName: "cylinder.fill", accessibilityDescription: nil) ?? NSImage())
            iconView.contentTintColor = .secondaryLabelColor
            iconView.translatesAutoresizingMaskIntoConstraints = false

            let innerStack = NSStackView(views: [iconView, cell.textField!])
            innerStack.orientation = .horizontal
            innerStack.spacing = 8
            innerStack.alignment = .centerY
            innerStack.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(innerStack)

            NSLayoutConstraint.activate([
                innerStack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                innerStack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                innerStack.topAnchor.constraint(equalTo: cell.topAnchor),
                innerStack.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 16),
                iconView.heightAnchor.constraint(equalToConstant: 16)
            ])

            configureDatabase(cell: cell, name: name)
            return cell
        }
    }

    private func configureDatabase(cell: NSTableCellView, name: String) {
        cell.textField?.stringValue = name
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        selectDatabase(at: tableView.selectedRow)
    }

    private func selectDatabase(at index: Int) {
        guard rows.indices.contains(index) else { return }
        guard case let .database(name) = rows[index] else { return }

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            guard let session = self.appModel.sessionManager.sessionForConnection(self.connectionID) else { return }
            await self.appModel.loadSchemaForDatabase(name, connectionSession: session)
            await MainActor.run {
                self.appModel.selectedConnectionID = self.connectionID
                self.view.window?.performClose(nil)
            }
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        applyFilter(searchField.stringValue)
    }
}
#endif
