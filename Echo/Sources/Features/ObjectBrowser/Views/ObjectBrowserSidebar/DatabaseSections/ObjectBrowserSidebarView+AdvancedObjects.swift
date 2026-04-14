import SwiftUI
import PostgresKit

extension ObjectBrowserSidebarView {

    @ViewBuilder
    func postgresAdvancedObjectsSection(database: DatabaseInfo, session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let dbKey = "\(connID.uuidString)-\(database.name)"
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful

        let isExpanded = Binding<Bool>(
            get: { viewModel.advancedObjectsExpandedByDB[dbKey] ?? false },
            set: { viewModel.advancedObjectsExpandedByDB[dbKey] = $0 }
        )

        folderHeaderRow(
            title: "Advanced",
            icon: "cube",
            count: nil,
            isExpanded: isExpanded,
            depth: 2
        )
        .contextMenu {
            Button {
                environmentState.openAdvancedObjectsTab(connectionID: connID)
            } label: {
                Label("Open Advanced Objects", systemImage: "cube")
            }
        }

        if isExpanded.wrappedValue {
            advancedObjectEntries(session: session, colored: colored)
        }
    }

    @ViewBuilder
    private func advancedObjectEntries(session: ConnectionSession, colored: Bool) -> some View {
        let connID = session.connection.id
        let entries: [(title: String, icon: String, section: PostgresAdvancedObjectsViewModel.Section)] = [
            ("Foreign Data Wrappers", "network", .foreignData),
            ("Event Triggers", "bolt", .eventTriggers),
            ("Domains", "d.square", .domains),
            ("Composite Types", "rectangle.3.group", .compositeTypes),
            ("Range Types", "arrow.left.and.right", .rangeTypes),
            ("Collations", "abc", .collations),
            ("Text Search", "magnifyingglass", .ftsConfig),
            ("Rules", "list.bullet.rectangle", .rules),
            ("Tablespaces", "externaldrive", .tablespaces),
            ("Aggregates", "function", .aggregates),
            ("Operators", "plus.forwardslash.minus", .operators),
            ("Languages", "chevron.left.forwardslash.chevron.right", .languages),
            ("Casts", "arrow.right.arrow.left", .casts),
        ]

        ForEach(entries, id: \.title) { entry in
            Button {
                environmentState.openAdvancedObjectsTab(connectionID: connID, section: entry.section)
            } label: {
                SidebarRow(
                    depth: 3,
                    icon: .system(entry.icon),
                    label: entry.title,
                    iconColor: ExplorerSidebarPalette.folderIconColor(title: entry.title, colored: colored)
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    environmentState.openAdvancedObjectsTab(connectionID: connID, section: entry.section)
                } label: {
                    Label("View \(entry.title)", systemImage: "arrow.up.right.square")
                }
            }
        }
    }
}
