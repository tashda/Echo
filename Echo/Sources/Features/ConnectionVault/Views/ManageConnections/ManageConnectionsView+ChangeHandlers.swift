import SwiftUI

struct ChangeHandlers: ViewModifier {
    let connectionStore: ConnectionStore
    let projectStore: ProjectStore
    @Binding var selectedSection: ManageSection?
    @Binding var sidebarSelection: SidebarSelection?
    @Binding var pendingConnectionMove: SavedConnection?
    @Binding var pendingIdentityMove: SavedIdentity?

    let filteredConnectionsForTable: [SavedConnection]
    let filteredIdentitiesForTable: [SavedIdentity]

    let onProjectChange: () -> Void
    let onSectionChange: (ManageSection) -> Void
    let onSidebarSelectionChange: (SidebarSelection?) -> Void
    let onFolderIDChange: (UUID?) -> Void
    let onConnectionsChange: ([SavedConnection.ID]) -> Void
    let onIdentitiesChange: ([SavedIdentity.ID]) -> Void
    let onFoldersChange: ([SavedFolder], [SavedFolder]) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: projectStore.selectedProject) { _, _ in onProjectChange() }
            .onChange(of: selectedSection) { _, newValue in
                if let section = newValue { onSectionChange(section) }
            }
            .onChange(of: connectionStore.selectedFolderID) { _, newValue in onFolderIDChange(newValue) }
            .onChange(of: connectionStore.connections) { _, newValue in onConnectionsChange(newValue.map(\.id)) }
            .onChange(of: connectionStore.identities) { _, newValue in onIdentitiesChange(newValue.map(\.id)) }
            .onChange(of: connectionStore.folders) { oldValue, newValue in onFoldersChange(oldValue, newValue) }
    }
}
