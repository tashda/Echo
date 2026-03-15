@preconcurrency import SwiftUI
import AppKit

struct ManageConnectionsView: View {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @Environment(NavigationStore.self) internal var navigationStore
    
    @EnvironmentObject internal var environmentState: EnvironmentState
    @EnvironmentObject internal var appState: AppState
    @EnvironmentObject internal var clipboardHistory: ClipboardHistoryStore
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

    // Project Management State
    @State internal var showDeleteConfirmation = false
    @State internal var projectToDelete: Project?
    @State internal var showExportSheet = false
    @State internal var showImportSheet = false
    @State internal var exportPassword = ""
    @State internal var importPassword = ""
    @State internal var includeGlobalSettings = true
    @State internal var includeClipboardHistory = true
    @State internal var includeAutocompleteHistory = true
    @State internal var exportError: String?
    @State internal var importError: String?
    @State internal var isExporting = false
    @State internal var isImporting = false
    @State internal var isPresentingNewProjectSheet = false
    @State internal var showResetSettingsConfirmation = false
    @State internal var exportProjectID: UUID?
    @State internal var isImportingSettings = false
    @State internal var lastImportedFrom: (name: String, date: Date)?
    @State internal var showIconPicker = false

    // New Import Settings State
    @State internal var showImportSettingsPopup = false
    @State internal var importSettingsSourceProject: Project?
    @State internal var importSettingsMerge = true
    @State internal var importIncludeSettings = true
    @State internal var importSelectedConnectionIDs = Set<UUID>()
    @State internal var importSelectedIdentityIDs = Set<UUID>()
    @State internal var importSelectedFolderIDs = Set<UUID>()

    @State internal var expandedSections: Set<ManageSection> = [.connections, .identities, .projects]
    @State internal var navHistory = NavigationHistory<SidebarSelection>()
    @State internal var sidebarVisibility: NavigationSplitViewVisibility = .automatic

    init(onClose: (() -> Void)? = nil, initialSection: ManageSection? = nil) {
        self.onClose = onClose
        if let initialSection {
            self._selectedSection = State(initialValue: initialSection)
            self._sidebarSelection = State(initialValue: .section(initialSection))
        }
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
            .sheet(isPresented: $showExportSheet) { exportSheet }
            .sheet(isPresented: $showImportSheet) { importSheet }
            .sheet(isPresented: $showImportSettingsPopup) { importSettingsSheet }
            .sheet(isPresented: $isPresentingNewProjectSheet) {
                NewProjectSheet()
                    .environment(projectStore)
                    .environment(navigationStore)
                    .environmentObject(environmentState)
            }
            .sheet(isPresented: $showIconPicker) {
                if case .project(let id) = sidebarSelection,
                   let project = projectStore.projects.first(where: { $0.id == id }) {
                    ProjectIconPickerSheet(project: project) { newIcon in
                        Task {
                            var updated = project
                            updated.iconName = newIcon
                            updated.updatedAt = Date()
                            try? await projectStore.updateProject(updated)
                        }
                    }
                    .environment(projectStore)
                }
            }
            .alert(
                "Delete Item?",
                isPresented: deletionAlertBinding,
                presenting: pendingDeletion,
                actions: deletionAlertActions,
                message: deletionAlertMessage
            )
            .alert("Delete Project?", isPresented: $showDeleteConfirmation, presenting: projectToDelete) { project in
                Button("Delete", role: .destructive) {
                    Task {
                        try? await projectStore.deleteProject(project)
                        if case .project(let id) = sidebarSelection, id == project.id {
                            sidebarSelection = .section(.projects)
                        }
                        projectToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { projectToDelete = nil }
            } message: { project in
                Text("Are you sure you want to delete '\(project.name)'? This will permanently delete all connections, identities, and folders in this project.")
            }
            .alert("Reset Settings?", isPresented: $showResetSettingsConfirmation) {
                Button("Reset", role: .destructive) {
                    if case .project(let id) = sidebarSelection {
                        Task { try? await projectStore.resetSettingsToDefault(for: id) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset all settings for this project to factory defaults. This cannot be undone.")
            }
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
            .modifier(ChangeActions(
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

}
