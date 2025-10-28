import AppKit

@MainActor
final class AppKitSettingsSidebarViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private let selectionModel: SettingsSelectionModel

    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()
    private let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("section"))

    private var items: [SettingsView.SettingsSection] = SettingsView.SettingsSection.allCases

    init(selectionModel: SettingsSelectionModel) {
        self.selectionModel = selectionModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        // Create background view with proper sidebar appearance like Xcode
        let backgroundView = NSVisualEffectView()
        backgroundView.material = .sidebar
        backgroundView.state = .active
        backgroundView.blendingMode = .withinWindow
        backgroundView.translatesAutoresizingMaskIntoConstraints = false

        // Configure outline view to match Xcode exactly
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.delegate = self
        outlineView.dataSource = self

        if #available(macOS 12.0, *) {
            outlineView.style = .sourceList
        } else {
            outlineView.selectionHighlightStyle = .sourceList
        }

        // Xcode's exact sidebar styling
        outlineView.rowHeight = 22
        outlineView.intercellSpacing = NSSize(width: 0, height: 1)
        outlineView.backgroundColor = .clear
        outlineView.translatesAutoresizingMaskIntoConstraints = false

        // Configure scroll view to match Xcode
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder

        // Set up view hierarchy
        backgroundView.addSubview(scrollView)
        self.view = backgroundView

        // Set up constraints
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),

            outlineView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            outlineView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            outlineView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            outlineView.bottomAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.bottomAnchor)
        ])

        // Set initial selection
        if let sel = selectionModel.selection, let idx = items.firstIndex(of: sel) {
            outlineView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        outlineView.reloadData()
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        items.count
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        false
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        items[index]
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let section = item as? SettingsView.SettingsSection else { return nil }
        let id = NSUserInterfaceItemIdentifier("cell")

        // Try to reuse existing cell view
        if let cell = outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
            cell.textField?.stringValue = section.title
            cell.imageView?.image = icon(for: section)
            return cell
        }

        // Create new cell view
        let cell = NSTableCellView()
        cell.identifier = id

        // Configure image view
        let imageView = NSImageView()
        imageView.image = icon(for: section)
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        cell.imageView = imageView

        // Configure text field
        let textField = NSTextField()
        textField.stringValue = section.title
        textField.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        textField.textColor = .labelColor
        textField.backgroundColor = .clear
        textField.isBordered = false
        textField.isEditable = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        cell.textField = textField

        // Add subviews
        cell.addSubview(imageView)
        cell.addSubview(textField)

        // Set up constraints to match Xcode exactly
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 16),
            imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16),

            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            textField.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -16)
        ])

        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        guard row >= 0, row < items.count else { return }
        selectionModel.setSelection(items[row])
    }

    private func icon(for section: SettingsView.SettingsSection) -> NSImage? {
        switch section.systemImage {
        case .some(let name):
            return NSImage(systemSymbolName: name, accessibilityDescription: nil)
        case .none:
            if let asset = section.assetImageName {
                return NSImage(named: asset)
            }
            return NSImage(systemSymbolName: "square", accessibilityDescription: nil)
        }
    }
}