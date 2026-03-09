import SwiftUI

extension TabOverviewView {
    var groupedTabs: [ServerGroup] {
        let grouped = Dictionary(grouping: tabs) { $0.connection.id }

        return grouped.keys.compactMap { id in
            guard let connection = connectionStore.connections.first(where: { $0.id == id }) else { return nil }
            let serverTabs = grouped[id] ?? []
            return ServerGroup(
                connection: connection,
                databaseGroups: databaseGroups(for: serverTabs),
                totalTabCount: serverTabs.count
            )
        }
    }

    func databaseGroups(for tabs: [WorkspaceTab]) -> [String: DatabaseGroup] {
        let grouped = Dictionary(grouping: tabs) { databaseKey(for: $0) }
        return grouped.mapValues { databaseTabs in
            DatabaseGroup(
                databaseName: databaseKey(for: databaseTabs[0]),
                sections: sectionGroups(for: databaseTabs)
            )
        }
    }

    func sectionGroups(for tabs: [WorkspaceTab]) -> [SectionGroup] {
        let grouped = Dictionary(grouping: tabs) { $0.kind }
        return WorkspaceTab.Kind.allCases.compactMap { kind in
            guard let kindTabs = grouped[kind], !kindTabs.isEmpty else { return nil }
            return SectionGroup(kind: kind, tabs: kindTabs)
        }
    }

    func databaseKey(for tab: WorkspaceTab) -> String {
        tab.connection.database.isEmpty ? "default" : tab.connection.database
    }

    var activeConnectionID: UUID? {
        environmentState.sessionCoordinator.activeConnectionID
    }

    var activeDatabaseName: String? {
        environmentState.sessionCoordinator.activeDatabaseName
    }

    var heroAccentColor: Color {
#if os(macOS)
        Color(nsColor: NSColor.controlAccentColor)
#else
        Color.accentColor
#endif
    }

    func databaseBackground(isActive: Bool) -> LinearGradient {
        let base = Color.white.opacity(colorScheme == .dark ? 0.04 : 0.7)
        let accent = heroAccentColor.opacity(isActive ? (colorScheme == .dark ? 0.28 : 0.14) : (colorScheme == .dark ? 0.16 : 0.08))
        return LinearGradient(
            colors: [
                base,
                accent
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
