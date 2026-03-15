@preconcurrency import SwiftUI

extension ManageConnectionsView {

    var displayedProject: Project? {
        if case .project(let id) = sidebarSelection {
            return projectStore.projects.first(where: { $0.id == id })
        }
        if case .section(.projects) = sidebarSelection {
            return projectStore.selectedProject ?? projectStore.projects.first
        }
        return nil
    }

    var configuredSplitView: some View {
        splitView
            .frame(minWidth: 1100, minHeight: 600)
    }

    var splitView: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            sidebar
                .frame(minWidth: 240)
                .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 400)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(NotificationCenter.default.publisher(for: .toggleManageConnectionsSidebar)) { _ in
            withAnimation {
                sidebarVisibility = sidebarVisibility == .detailOnly ? .automatic : .detailOnly
            }
        }
    }

    var deletionAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { isPresented in
                if !isPresented { pendingDeletion = nil }
            }
        )
    }

    @ViewBuilder
    func folderEditorSheet(_ state: FolderEditorState) -> some View {
        FolderEditorSheet(state: state)
            .environmentObject(environmentState)
    }

    @ViewBuilder
    func identityEditorSheet(_ state: IdentityEditorState) -> some View {
        IdentityEditorSheet(state: state)
            .environmentObject(environmentState)
    }

    @ViewBuilder
    func connectionEditorSheet(_ presentation: ConnectionEditorPresentation) -> some View {
        ConnectionEditorView(connection: presentation.connection) { connection, password, action in
            handleConnectionEditorSave(connection: connection, password: password, action: action)
        }
        .environment(projectStore)
        .environment(connectionStore)
        .environment(navigationStore)
        .environmentObject(environmentState)
        .environmentObject(appState)
    }

    @ViewBuilder
    func deletionAlertActions(target: DeletionTarget) -> some View {
        Button("Delete", role: .destructive) { performDeletion(for: target) }
        Button("Cancel", role: .cancel) { pendingDeletion = nil }
    }

    @ViewBuilder
    func deletionAlertMessage(target: DeletionTarget) -> some View {
        Text("Are you sure you want to delete \(target.displayName)? This action cannot be undone.")
    }
}
