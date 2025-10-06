import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

// MARK: - Test View Entry Point

/// Test view demonstrating native macOS approaches for connection management
///
/// This file contains two implementations:
/// 1. Pure SwiftUI using List + OutlineGroup (SwiftUI-native)
/// 2. NSOutlineView wrapped in NSViewRepresentable (AppKit-native)
///
/// Both provide the same functionality as ManageConnectionsTab but using native components.
struct NativeConnectionsTestView: View {
    @State private var selectedApproach: TestApproach = .swiftUIOutline

    enum TestApproach: String, CaseIterable, Identifiable {
        case swiftUIOutline = "SwiftUI List + OutlineGroup"
        case appKitOutlineView = "AppKit NSOutlineView"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Approach selector
            Picker("Approach", selection: $selectedApproach) {
                ForEach(TestApproach.allCases) { approach in
                    Text(approach.rawValue).tag(approach)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Display selected approach
            Group {
                switch selectedApproach {
                case .swiftUIOutline:
                    SwiftUIOutlineTestView()
                case .appKitOutlineView:
                    AppKitOutlineTestView()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

// MARK: - Approach 1: SwiftUI List + OutlineGroup

struct SwiftUIOutlineTestView: View {
    @StateObject private var viewModel = TestConnectionsViewModel()
    @State private var searchText = ""
    @State private var selection: TreeNode.ID?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    NavigationLink(value: "connections") {
                        Label("Connections", systemImage: "externaldrive")
                    }
                    NavigationLink(value: "identities") {
                        Label("Identities", systemImage: "person.crop.circle")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 260)
        } detail: {
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)

                    Spacer()

                    Button(action: viewModel.addConnection) {
                        Label("New Connection", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: viewModel.addFolder) {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()

                Divider()

                // Native List with OutlineGroup
                List(selection: $selection) {
                    OutlineGroup(
                        viewModel.tree,
                        id: \.id,
                        children: \.children
                    ) { node in
                        nodeRow(for: node)
                    }
                }
                .listStyle(.plain)
                .alternatingRowBackgrounds()
            }
        }
    }

    @ViewBuilder
    private func nodeRow(for node: TreeNode) -> some View {
        switch node.type {
        case .folder(let name):
            Label(name, systemImage: "folder.fill")
                .contextMenu {
                    Button("Rename") { }
                    Button("Delete", role: .destructive) { }
                }
                .draggable(node.id.uuidString)
                .dropDestination(for: String.self) { items, location in
                    // Handle drop
                    return true
                }
        case .connection(let connection):
            HStack {
                Image(systemName: "server.rack")
                    .frame(width: 32, height: 32)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.name)
                        .font(.system(size: 13, weight: .medium))
                    Text("\(connection.host):\(connection.port)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Connect") {
                    viewModel.connect(to: connection)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .contextMenu {
                Button("Connect") { viewModel.connect(to: connection) }
                Button("Edit") { }
                Divider()
                Button("Delete", role: .destructive) { }
            }
            .draggable(node.id.uuidString)
        }
    }
}

// MARK: - Approach 2: AppKit NSOutlineView

struct AppKitOutlineTestView: View {
    @StateObject private var viewModel = TestConnectionsViewModel()
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            List {
                Section {
                    Label("Connections", systemImage: "externaldrive")
                    Label("Identities", systemImage: "person.crop.circle")
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 260)
        } detail: {
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)

                    Spacer()

                    Button(action: viewModel.addConnection) {
                        Label("New Connection", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: viewModel.addFolder) {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()

                Divider()

                // Native NSOutlineView
                NativeOutlineView(
                    tree: viewModel.tree,
                    onConnect: viewModel.connect,
                    onEdit: { _ in },
                    onDelete: { _ in }
                )
            }
        }
    }
}

// MARK: - NSOutlineView Wrapper

struct NativeOutlineView: NSViewRepresentable {
    let tree: [TreeNode]
    let onConnect: (TestConnection) -> Void
    let onEdit: (TreeNode) -> Void
    let onDelete: (TreeNode) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let outlineView = NSOutlineView()

        // Configure outline view
        outlineView.dataSource = context.coordinator
        outlineView.delegate = context.coordinator
        outlineView.headerView = nil
        outlineView.rowSizeStyle = .default
        outlineView.usesAlternatingRowBackgroundColors = true
        outlineView.autoresizesOutlineColumn = false
        outlineView.indentationPerLevel = 16
        outlineView.style = .sourceList

        // Enable drag and drop
        outlineView.registerForDraggedTypes([.string])
        outlineView.setDraggingSourceOperationMask([.move], forLocal: true)

        // Create columns
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.minWidth = 200
        nameColumn.resizingMask = .autoresizingMask
        outlineView.addTableColumn(nameColumn)
        outlineView.outlineTableColumn = nameColumn

        let actionsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("actions"))
        actionsColumn.title = "Actions"
        actionsColumn.width = 150
        actionsColumn.minWidth = 150
        actionsColumn.maxWidth = 200
        outlineView.addTableColumn(actionsColumn)

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true

        context.coordinator.outlineView = outlineView
        context.coordinator.tree = tree

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.tree = tree
        context.coordinator.onConnect = onConnect
        context.coordinator.onEdit = onEdit
        context.coordinator.onDelete = onDelete

        if let outlineView = scrollView.documentView as? NSOutlineView {
            outlineView.reloadData()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        weak var outlineView: NSOutlineView?
        var tree: [TreeNode] = []
        var onConnect: (TestConnection) -> Void = { _ in }
        var onEdit: (TreeNode) -> Void = { _ in }
        var onDelete: (TreeNode) -> Void = { _ in }

        // MARK: - Data Source

        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            if item == nil {
                return tree.count
            }
            if let node = item as? TreeNode {
                return node.children?.count ?? 0
            }
            return 0
        }

        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            if item == nil {
                return tree[index]
            }
            if let node = item as? TreeNode {
                return node.children?[index] ?? TreeNode.placeholder
            }
            return TreeNode.placeholder
        }

        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            if let node = item as? TreeNode {
                return !(node.children?.isEmpty ?? true)
            }
            return false
        }

        // MARK: - Delegate

        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let node = item as? TreeNode,
                  let columnIdentifier = tableColumn?.identifier else {
                return nil
            }

            if columnIdentifier.rawValue == "name" {
                return makeNameView(for: node, in: outlineView)
            } else if columnIdentifier.rawValue == "actions" {
                return makeActionsView(for: node, in: outlineView)
            }

            return nil
        }

        func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
            return 44
        }

        // MARK: - Drag and Drop

        func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
            guard let node = item as? TreeNode else { return nil }
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(node.id.uuidString, forType: .string)
            return pasteboardItem
        }

        func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
            // Only allow drops on folders
            if let node = item as? TreeNode, case .folder = node.type {
                return .move
            }
            if item == nil { // Root
                return .move
            }
            return []
        }

        func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
            // Handle the drop
            print("Dropped onto: \(String(describing: item))")
            return true
        }

        // MARK: - View Creation

        private func makeNameView(for node: TreeNode, in outlineView: NSOutlineView) -> NSView {
            let view = NSTableCellView()

            switch node.type {
            case .folder(let name):
                let imageView = NSImageView()
                imageView.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
                imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                imageView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(imageView)

                let textField = NSTextField(labelWithString: name)
                textField.font = .systemFont(ofSize: 13, weight: .medium)
                textField.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(textField)

                NSLayoutConstraint.activate([
                    imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
                    imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    imageView.widthAnchor.constraint(equalToConstant: 16),
                    imageView.heightAnchor.constraint(equalToConstant: 16),

                    textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                    textField.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    textField.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -4)
                ])

            case .connection(let connection):
                let iconView = NSView()
                iconView.wantsLayer = true
                iconView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.2).cgColor
                iconView.layer?.cornerRadius = 6
                iconView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(iconView)

                let imageView = NSImageView()
                imageView.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)
                imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
                imageView.contentTintColor = .systemBlue
                imageView.translatesAutoresizingMaskIntoConstraints = false
                iconView.addSubview(imageView)

                let stackView = NSStackView()
                stackView.orientation = .vertical
                stackView.alignment = .leading
                stackView.spacing = 2
                stackView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(stackView)

                let nameLabel = NSTextField(labelWithString: connection.name)
                nameLabel.font = .systemFont(ofSize: 13, weight: .medium)

                let hostLabel = NSTextField(labelWithString: "\(connection.host):\(connection.port)")
                hostLabel.font = .systemFont(ofSize: 11)
                hostLabel.textColor = .secondaryLabelColor

                stackView.addArrangedSubview(nameLabel)
                stackView.addArrangedSubview(hostLabel)

                NSLayoutConstraint.activate([
                    iconView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
                    iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    iconView.widthAnchor.constraint(equalToConstant: 32),
                    iconView.heightAnchor.constraint(equalToConstant: 32),

                    imageView.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
                    imageView.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

                    stackView.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
                    stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -4)
                ])
            }

            return view
        }

        private func makeActionsView(for node: TreeNode, in outlineView: NSOutlineView) -> NSView? {
            guard case .connection(let connection) = node.type else {
                return nil
            }

            let view = NSView()

            let button = NSButton(title: "Connect", target: self, action: #selector(connectButtonClicked(_:)))
            button.bezelStyle = .rounded
            button.translatesAutoresizingMaskIntoConstraints = false
            button.tag = node.id.hashValue
            view.addSubview(button)

            NSLayoutConstraint.activate([
                button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
                button.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])

            return view
        }

        @objc private func connectButtonClicked(_ sender: NSButton) {
            // Find node by tag/id and call onConnect
            print("Connect clicked")
        }
    }
}

// MARK: - Test Data Models

class TestConnectionsViewModel: ObservableObject {
    @Published var tree: [TreeNode] = []

    init() {
        loadTestData()
    }

    private func loadTestData() {
        tree = [
            TreeNode(
                type: .folder("Production"),
                children: [
                    TreeNode(type: .connection(TestConnection(name: "Main DB", host: "prod.example.com", port: 5432))),
                    TreeNode(type: .connection(TestConnection(name: "Analytics DB", host: "analytics.example.com", port: 5432))),
                ]
            ),
            TreeNode(
                type: .folder("Development"),
                children: [
                    TreeNode(type: .connection(TestConnection(name: "Local DB", host: "localhost", port: 5432))),
                    TreeNode(type: .connection(TestConnection(name: "Test DB", host: "test.example.com", port: 5432))),
                ]
            ),
            TreeNode(type: .connection(TestConnection(name: "Staging DB", host: "staging.example.com", port: 5432))),
        ]
    }

    func addConnection() {
        print("Add connection")
    }

    func addFolder() {
        print("Add folder")
    }

    func connect(to connection: TestConnection) {
        print("Connect to: \(connection.name)")
    }
}

struct TreeNode: Identifiable {
    let id = UUID()
    let type: NodeType
    var children: [TreeNode]?

    enum NodeType {
        case folder(String)
        case connection(TestConnection)
    }

    static let placeholder = TreeNode(type: .folder(""))
}

struct TestConnection: Identifiable {
    let id = UUID()
    let name: String
    let host: String
    let port: Int
}

// MARK: - SwiftUI List Styling Extension

private extension View {
    func alternatingRowBackgrounds() -> some View {
        // This is a placeholder - actual implementation would need more work
        self
    }
}

// MARK: - Preview

#Preview {
    NativeConnectionsTestView()
}
