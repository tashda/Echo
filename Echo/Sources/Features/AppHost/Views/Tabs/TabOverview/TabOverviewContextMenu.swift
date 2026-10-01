import SwiftUI

extension TabOverviewView {
    @ViewBuilder
    func tabContextMenu(for tab: WorkspaceTab, serverID: UUID, databaseIdentifier: String) -> some View {
        Button {
            onSelectTab(tab.id)
        } label: {
            Label("Select Tab", systemImage: "hand.tap")
        }

        Divider()

        Button {
            duplicateTab(tab)
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }

        if !tab.isPinned {
            Button {
                pinTab(tab)
            } label: {
                Label("Pin Tab", systemImage: "pin")
            }
        } else {
            Button {
                unpinTab(tab)
            } label: {
                Label("Unpin Tab", systemImage: "pin.slash")
            }
        }

        Divider()

        let databases = environmentState.switchableDatabaseNames(for: tab)
        if !databases.isEmpty {
            // Tabs move between databases on their own server; a tab can't change server (plan O2).
            Menu("Switch Database", systemImage: "cylinder.split.1x2") {
                ForEach(databases, id: \.self) { database in
                    Button {
                        environmentState.switchDatabase(database, for: tab)
                    } label: {
                        if database == tab.activeDatabaseName {
                            Label(database, systemImage: "checkmark")
                        } else {
                            Text(database)
                        }
                    }
                    .disabled(database == tab.activeDatabaseName)
                }
            }
        }

        Divider()

        Button(role: .destructive) {
            onCloseTab(tab.id)
        } label: {
            Label("Close Tab", systemImage: "xmark")
        }
    }

    private func duplicateTab(_ tab: WorkspaceTab) {
        environmentState.duplicateTab(tab)
    }

    private func pinTab(_ tab: WorkspaceTab) {
        tabStore.togglePin(for: tab.id)
    }

    private func unpinTab(_ tab: WorkspaceTab) {
        tabStore.togglePin(for: tab.id)
    }
}
