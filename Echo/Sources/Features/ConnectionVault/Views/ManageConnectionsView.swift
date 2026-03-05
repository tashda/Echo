@preconcurrency import SwiftUI
import AppKit

@MainActor
struct ManageConnectionsView: View {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @Environment(NavigationStore.self) internal var navigationStore
    
    @EnvironmentObject internal var environmentState: EnvironmentState
    @EnvironmentObject internal var appState: AppState
    @ObservedObject internal var appearanceStore = AppearanceStore.shared
    @Environment(\.dismiss) internal var dismiss
    internal let onClose: (() -> Void)?

    @State internal var selectedSection: ManageSection? = .connections
    @State internal var sidebarSelection: SidebarSelection? = .section(.connections)
    @State internal var searchText = ""
    @State internal var folderEditorState: FolderEditorState?
    @State internal var identityEditorState: IdentityEditorState?
    @State internal var pendingDeletion: DeletionTarget?
    @State internal var connectionEditorPresentation: ConnectionEditorPresentation?
    @State internal var pendingDuplicateConnection: SavedConnection?
    @State internal var pendingConnectionMove: SavedConnection?
    @State internal var pendingIdentityMove: SavedIdentity?
    @State internal var connectionSelection = Set<SavedConnection.ID>()
    @State internal var identitySelection = Set<SavedIdentity.ID>()
    @State internal var connectionSortOrder: [KeyPathComparator<SavedConnection>] = []
    @State internal var identitySortOrder: [KeyPathComparator<SavedIdentity>] = []

    @State internal var expandedSections: Set<ManageSection> = [.connections, .identities]

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    internal var activeSection: ManageSection { selectedSection ?? .connections }

    var body: some View {
        contentView
            .onAppear(perform: ensureSectionSelection)
            .onAppear {
                if connectionSortOrder.isEmpty {
                    connectionSortOrder = [KeyPathComparator(\SavedConnection.connectionName, order: .forward)]
                }
                if identitySortOrder.isEmpty {
                    identitySortOrder = [KeyPathComparator(\SavedIdentity.name, order: .forward)]
                }
            }
    }

    private var contentView: some View {
        configuredSplitView
            .preferredColorScheme(appearanceStore.effectiveColorScheme)
            .sheet(item: $folderEditorState, content: folderEditorSheet)
            .sheet(item: $identityEditorState, content: identityEditorSheet)
            .sheet(item: $connectionEditorPresentation, content: connectionEditorSheet)
            .alert(
                "Delete Item?",
                isPresented: deletionAlertBinding,
                presenting: pendingDeletion,
                actions: deletionAlertActions,
                message: deletionAlertMessage
            )
            .confirmationDialog(
                "Duplicate Connection",
                isPresented: Binding(
                    get: { pendingDuplicateConnection != nil },
                    set: { isPresented in
                        if !isPresented { pendingDuplicateConnection = nil }
                    }
                ),
                titleVisibility: .visible,
                presenting: pendingDuplicateConnection
            ) { connection in
                Button("Duplicate with Bookmark History") {
                    performDuplicate(connection, copyBookmarks: true)
                }

                Button("Duplicate Only Connection") {
                    performDuplicate(connection, copyBookmarks: false)
                }

                Button("Cancel", role: .cancel) {
                    pendingDuplicateConnection = nil
                }
            } message: { _ in
                Text("Do you want to copy the bookmark history into the duplicated connection?")
            }
            .modifier(ChangeHandlers(
                connectionStore: connectionStore,
                projectStore: projectStore,
                selectedSection: $selectedSection,
                sidebarSelection: $sidebarSelection,
                pendingConnectionMove: $pendingConnectionMove,
                pendingIdentityMove: $pendingIdentityMove,
                filteredConnectionsForTable: filteredConnectionsForTable,
                filteredIdentitiesForTable: filteredIdentitiesForTable,
                onProjectChange: resetForProjectChange,
                onSectionChange: handleSectionChange,
                onSidebarSelectionChange: handleSidebarSelectionChange,
                onFolderIDChange: syncSidebarSelection,
                onConnectionsChange: { pruneConnectionSelection(allowedIDs: Set($0)) },
                onIdentitiesChange: { pruneIdentitySelection(allowedIDs: Set($0)) },
                onFoldersChange: handleFoldersChange
            ))
    }

    private var configuredSplitView: some View {
        splitView
            .frame(minWidth: 900, minHeight: 600)
    }

    private var splitView: some View {
        NavigationSplitView {
            sidebar
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 300)
#if os(macOS)
                .toolbar(removing: .sidebarToggle)
#endif
        } detail: {
            detailContent
        }
#if os(macOS)
        .navigationSplitViewStyle(.balanced)
#endif
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
