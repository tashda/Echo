import SwiftUI

#if os(macOS)
import AppKit

struct DoubleClickableTable<Content: View>: NSViewRepresentable {
    let connections: [SavedConnection]
    @Binding var selection: Set<SavedConnection.ID>
    let onDoubleClick: (SavedConnection) -> Void
    let content: Content
    @ObservedObject private var appearanceStore = AppearanceStore.shared

    init(
        connections: [SavedConnection],
        selection: Binding<Set<SavedConnection.ID>>,
        onDoubleClick: @escaping (SavedConnection) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.connections = connections
        self._selection = selection
        self.onDoubleClick = onDoubleClick
        self.content = content()
    }

    func makeNSView(context: Context) -> NSHostingView<Content> {
        let hostingView = NSHostingView(rootView: content)

        DispatchQueue.main.async {
            if let tableView = findTableView(in: hostingView) {
                tableView.doubleAction = #selector(Coordinator.tableViewDoubleClicked(_:))
                tableView.target = context.coordinator
                applyTableTheme(tableView, appearanceStore: appearanceStore)
                context.coordinator.tableView = tableView
            }
        }

        return hostingView
    }

    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
        nsView.rootView = content
        context.coordinator.connections = connections
        context.coordinator.selection = selection
        context.coordinator.onDoubleClick = onDoubleClick
        if let tableView = context.coordinator.tableView {
            applyTableTheme(tableView, appearanceStore: appearanceStore)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(connections: connections, selection: selection, onDoubleClick: onDoubleClick)
    }

    private func findTableView(in view: NSView) -> NSTableView? {
        if let tableView = view as? NSTableView {
            return tableView
        }
        for subview in view.subviews {
            if let found = findTableView(in: subview) {
                return found
            }
        }
        return nil
    }

    @MainActor
    class Coordinator: NSObject {
        var connections: [SavedConnection]
        var selection: Set<SavedConnection.ID>
        var onDoubleClick: (SavedConnection) -> Void
        weak var tableView: NSTableView?

        init(connections: [SavedConnection], selection: Set<SavedConnection.ID>, onDoubleClick: @escaping (SavedConnection) -> Void) {
            self.connections = connections
            self.selection = selection
            self.onDoubleClick = onDoubleClick
        }

        @objc func tableViewDoubleClicked(_ sender: NSTableView) {
            guard sender.clickedRow >= 0,
                  sender.clickedRow < connections.count else { return }

            let connection = connections[sender.clickedRow]
            onDoubleClick(connection)
        }
    }
}

@MainActor
func applyTableTheme(_ tableView: NSTableView, appearanceStore: AppearanceStore) {
    let isDark = appearanceStore.effectiveColorScheme == .dark
    tableView.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    let base = NSColor(ColorTokens.Background.secondary)
    tableView.backgroundColor = base
    tableView.usesAlternatingRowBackgroundColors = false
    tableView.selectionHighlightStyle = .regular
    tableView.intercellSpacing = NSSize(width: 0, height: 0)
    tableView.enclosingScrollView?.drawsBackground = true
    tableView.enclosingScrollView?.backgroundColor = base
    tableView.gridColor = NSColor(ColorTokens.Text.primary).withAlphaComponent(0.12)
}
#endif
