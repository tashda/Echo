import SwiftUI

#if os(macOS)
import AppKit

@MainActor
final class DatabasePopoverController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSSearchFieldDelegate {
    let environmentState: EnvironmentState
    let connectionID: UUID

    private var all: [String] = []
    var rows: [String] = []
    var loadTask: Task<Void, Never>?

    private let searchField = NSSearchField(frame: .zero)
    let tableView = NSTableView(frame: .zero)
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
        tableView.style = .sourceList
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
            guard let session = self.environmentState.sessionCoordinator.sessionForConnection(self.connectionID) else {
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

    func applyFilter(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let filter: (String) -> Bool = { name in
            guard !trimmed.isEmpty else { return true }
            return name.localizedCaseInsensitiveContains(trimmed)
        }

        rows = all.filter(filter)
        tableView.reloadData()
        updateSelection()
    }

    private func updateSelection() {
        guard let selectedName = environmentState.sessionCoordinator.sessionForConnection(connectionID)?.selectedDatabaseName,
              let index = rows.firstIndex(of: selectedName) else {
            tableView.deselectAll(nil)
            return
        }
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }

    func controlTextDidChange(_ obj: Notification) {
        applyFilter(searchField.stringValue)
    }
}
#endif
