import SwiftUI

#if os(macOS)
import AppKit

@MainActor
final class ConnectionsPopoverController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSSearchFieldDelegate {
    let connectionStore: ConnectionStore
    let environmentState: EnvironmentState
    var rows: [SavedConnection] = []
    private var all: [SavedConnection] = []

    private let searchField = NSSearchField(frame: .zero)
    let tableView = HoverTableView(frame: .zero)
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
        actionsStack.addArrangedSubview(makeActionButton(title: "New Connection\u{2026}", action: #selector(openNewConnection)))
        actionsStack.addArrangedSubview(makeActionButton(title: "Manage Connections\u{2026}", action: #selector(openManageConnections)))
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

    func applyFilter(_ text: String) {
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

    func controlTextDidChange(_ obj: Notification) {
        applyFilter(searchField.stringValue)
    }
}
#endif
