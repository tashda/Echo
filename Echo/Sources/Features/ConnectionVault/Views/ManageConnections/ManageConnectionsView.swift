@preconcurrency import SwiftUI
import AppKit

/// Manage Connections (round MC): a three-column window. The sidebar picks the scope (all or
/// recently used connections, or identities) under a project switcher; the middle column lists
/// them, as two-line rows or a table; the right column edits the selection in place.
struct ManageConnectionsView: View {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @Environment(NavigationStore.self) internal var navigationStore
    @Environment(EnvironmentState.self) internal var environmentState
    @Environment(AppState.self) internal var appState
    @Environment(ClipboardHistoryStore.self) internal var clipboardHistory
    @Environment(AppearanceStore.self) internal var appearanceStore
    @Environment(AuthState.self) internal var authState
    @Environment(\.dismiss) internal var dismiss
    internal let onClose: (() -> Void)?

    // MARK: Navigation
    @State internal var scope: ManageScope? = .allConnections
    @AppStorage("manageConnections.viewMode") internal var viewModeRawValue = ConnectionsViewMode.list.rawValue
    @State internal var searchText = ""
    @State internal var connectionSelection = Set<SavedConnection.ID>()
    @State internal var identitySelection = Set<SavedIdentity.ID>()
    @State internal var connectionSortOrder = [KeyPathComparator(\ConnectionTableItem.name, comparator: .localizedStandard)]
    @State internal var identitySortOrder = [KeyPathComparator(\SavedIdentity.name, comparator: .localizedStandard)]
    @State internal var sidebarVisibility: NavigationSplitViewVisibility = .all

    // MARK: Editing
    /// R2-B (NB1): a new connection is being made in the pane.
    @State internal var isCreatingConnection = false
    @State internal var isCreatingIdentity = false
    /// Whether the editor in the right column has unsaved changes.
    @State internal var detailHasChanges = false
    /// What stops the editor saving (a missing field), or nil. The leave alert offers Save only
    /// when this is nil.
    @State internal var detailSaveBlocker: String?
    /// A move away from unsaved changes, waiting for the answer to "Save changes?" (MC1).
    @State internal var pendingNavigation: PendingNavigation?
    /// Where to go once a save asked for by that alert has finished.
    @State internal var navigationAfterSave: PendingNavigation?
    /// Bumped to ask the editor to save; bumped revision rebuilds it from the saved values.
    @State internal var saveRequest = 0
    @State internal var editorRevision = 0
    @State internal var pendingDeletion: DeletionTarget?
    @State internal var pendingDuplicateConnection: SavedConnection?

    // MARK: Folders
    @State internal var folderNameRequest: FolderNameRequest?
    @State internal var folderNameDraft = ""
    @State internal var pendingFolderDeletion: SavedFolder?
    /// Folder headings closed in the list and table (R2-G).
    @State internal var collapsedGroupIDs = Set<UUID>()
    /// The table's inspector was closed by hand; it opens again on the next selection (R2-A).
    @State internal var isInspectorDismissed = false

    // MARK: Projects
    @State internal var isShowingProjectSettings = false
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
    @State internal var showIconPicker = false
    @State internal var showImportSettingsPopup = false
    @State internal var importSettingsSourceProject: Project?
    @State internal var importSettingsMerge = true
    @State internal var importIncludeSettings = true
    @State internal var importSelectedConnectionIDs = Set<UUID>()
    @State internal var importSelectedIdentityIDs = Set<UUID>()

    init(onClose: (() -> Void)? = nil, initialSection: ManageSection? = nil, initialProjectID: UUID? = nil, initialConnectionID: UUID? = nil, startsNewConnection: Bool = false) {
        self.onClose = onClose
        switch initialSection {
        case .identities?: _scope = State(initialValue: .identities)
        case .projects?: _isShowingProjectSettings = State(initialValue: true)
        default: break
        }
        if initialProjectID != nil { _isShowingProjectSettings = State(initialValue: true) }
        if let initialConnectionID { _connectionSelection = State(initialValue: [initialConnectionID]) }
        // The server trail's New Connection (round 52) opens the sheet at once.
        if startsNewConnection { _isCreatingConnection = State(initialValue: true) }
    }

    internal var activeScope: ManageScope { scope ?? .allConnections }

    internal var viewMode: ConnectionsViewMode {
        get { ConnectionsViewMode(rawValue: viewModeRawValue) ?? .list }
        nonmutating set { viewModeRawValue = newValue.rawValue }
    }

    var body: some View {
        splitView
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 920, minHeight: 560)
        .navigationTitle(scopeTitle)
        .navigationSubtitle(countText)
        .preferredColorScheme(appearanceStore.effectiveColorScheme)
        .onReceive(NotificationCenter.default.publisher(for: .toggleManageConnectionsSidebar)) { _ in
            withAnimation {
                sidebarVisibility = sidebarVisibility == .doubleColumn ? .all : .doubleColumn
            }
        }
        .onChange(of: projectStore.selectedProject?.id) { _, _ in resetForProjectChange() }
        .onChange(of: connectionStore.connections.map(\.id)) { _, ids in connectionSelection.formIntersection(Set(ids)) }
        .onChange(of: connectionStore.identities.map(\.id)) { _, ids in identitySelection.formIntersection(Set(ids)) }
        .onChange(of: connectionSelection) { _, _ in isInspectorDismissed = false }
        .onChange(of: identitySelection) { _, _ in isInspectorDismissed = false }
        .modifier(ManageConnectionsSheets(view: self))
        .modifier(ManageConnectionsAlerts(view: self))
        .modifier(ManageConnectionsFolderAlerts(view: self))
    }

    // MARK: Layout (R2-A, PA1)

    /// List mode: three columns, the editor always beside the list. Table mode: the table takes
    /// the whole width and the editor slides in as an inspector when one row is selected.
    @ViewBuilder
    private var splitView: some View {
        if viewMode == .table {
            NavigationSplitView(columnVisibility: $sidebarVisibility) {
                sidebar
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            } detail: {
                contentWithChrome
                    .inspector(isPresented: inspectorBinding) {
                        detailColumn
                            .inspectorColumnWidth(min: 380, ideal: 440, max: 560)
                    }
            }
        } else {
            NavigationSplitView(columnVisibility: $sidebarVisibility) {
                sidebar
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            } content: {
                contentWithChrome
                    .navigationSplitViewColumnWidth(min: 300, ideal: 380, max: 460)
            } detail: {
                detailColumn
                    .navigationSplitViewColumnWidth(min: 400, ideal: 460)
            }
        }
    }

    /// R2-C (TB1): the list's own controls (view switch, add, search) sit over the list, so
    /// nothing crosses the line between the list and the editor.
    private var contentWithChrome: some View {
        contentColumn
            .searchable(text: $searchText, placement: .toolbar, prompt: activeScope.isConnections ? "Search connections" : "Search identities")
            .toolbar { toolbarContent }
    }

    /// The table's inspector shows one selected row, or a new connection or identity.
    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: {
                guard !isInspectorDismissed else { return false }
                if activeScope.isConnections { return isCreatingConnection || connectionSelection.count == 1 }
                return isCreatingIdentity || identitySelection.count == 1
            },
            set: { shown in
                if !shown { isInspectorDismissed = true }
            }
        )
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Picker("View", selection: Binding(get: { viewMode }, set: { viewMode = $0 })) {
                Label("List", systemImage: "list.bullet").tag(ConnectionsViewMode.list)
                Label("Table", systemImage: "tablecells").tag(ConnectionsViewMode.table)
            }
            .pickerStyle(.segmented)
            .labelStyle(.iconOnly)
            .help("Show as a list or a table")
        }
        ToolbarItem(placement: .automatic) {
            Menu {
                Button {
                    navigate(to: .newConnection)
                } label: {
                    Label("New Connection…", systemImage: "externaldrive.badge.plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                Button {
                    navigate(to: .newIdentity)
                } label: {
                    Label("New Identity", systemImage: "person.crop.circle.badge.plus")
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
                Divider()
                Button {
                    beginNewFolder(kind: currentFolderKind, parentID: currentFolderID)
                } label: {
                    Label("New Folder…", systemImage: "folder.badge.plus")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            } label: {
                Label("Add", systemImage: "plus")
            } primaryAction: {
                navigate(to: activeScope.isConnections ? .newConnection : .newIdentity)
            }
            .menuIndicator(.hidden)
            .help(activeScope.isConnections ? "New Connection (⌘N)" : "New Identity (⌥⌘N)")
        }
    }

    private var countText: String {
        if activeScope.isConnections {
            let count = scopedConnections.count
            return count == 1 ? "1 connection" : "\(count) connections"
        }
        let count = scopedIdentities.count
        return count == 1 ? "1 identity" : "\(count) identities"
    }
}

// MARK: - Sheets

/// The window's sheets, kept apart so the main body stays readable.
private struct ManageConnectionsSheets: ViewModifier {
    let view: ManageConnectionsView

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: view.$isShowingProjectSettings) { view.projectSettingsSheet }
            .sheet(isPresented: view.$showExportSheet) { view.exportSheet }
            .sheet(isPresented: view.$showImportSheet) { view.importSheet }
            .sheet(isPresented: view.$showImportSettingsPopup) { view.importSettingsSheet }
            .sheet(isPresented: view.$isPresentingNewProjectSheet) {
                NewProjectSheet()
                    .environment(view.projectStore)
                    .environment(view.navigationStore)
                    .environment(view.environmentState)
            }
            .sheet(isPresented: view.$showIconPicker) {
                if let project = view.projectStore.selectedProject {
                    ProjectIconPickerSheet(project: project) { newIcon in
                        Task {
                            var updated = project
                            updated.iconName = newIcon
                            updated.updatedAt = Date()
                            try? await view.projectStore.updateProject(updated)
                        }
                    }
                    .environment(view.projectStore)
                }
            }
    }
}

// MARK: - Alerts

private struct ManageConnectionsAlerts: ViewModifier {
    let view: ManageConnectionsView

    func body(content: Content) -> some View {
        content
            .alert(
                view.leaveAlertTitle,
                isPresented: Binding(
                    get: { view.pendingNavigation != nil },
                    set: { if !$0 { view.pendingNavigation = nil } }
                )
            ) {
                if view.detailSaveBlocker == nil {
                    Button("Save") { view.saveThenContinue() }
                        .keyboardShortcut(.defaultAction)
                    Button("Don't Save", role: .destructive) { view.discardThenContinue() }
                } else {
                    Button("Discard Changes", role: .destructive) { view.discardThenContinue() }
                }
                Button("Cancel", role: .cancel) { view.pendingNavigation = nil }
            } message: {
                if let blocker = view.detailSaveBlocker {
                    Text("They can't be saved yet. \(blocker)")
                } else {
                    Text("Your changes are lost if you don't save them.")
                }
            }
            .alert(
                view.pendingDeletion.map { "Delete “\($0.displayName)”?" } ?? "Delete?",
                isPresented: Binding(
                    get: { view.pendingDeletion != nil },
                    set: { if !$0 { view.pendingDeletion = nil } }
                ),
                presenting: view.pendingDeletion
            ) { target in
                Button("Delete", role: .destructive) { view.performDeletion(for: target) }
                Button("Cancel", role: .cancel) { view.pendingDeletion = nil }
            } message: { target in
                Text(view.deletionMessage(for: target))
            }
            .alert("Delete Project?", isPresented: view.$showDeleteConfirmation, presenting: view.projectToDelete) { project in
                Button("Delete", role: .destructive) {
                    Task {
                        try? await view.projectStore.deleteProject(project)
                        view.projectToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { view.projectToDelete = nil }
            } message: { project in
                Text("“\(project.name)” and its connections and identities are deleted. This can't be undone.")
            }
            .alert("Reset Settings?", isPresented: view.$showResetSettingsConfirmation) {
                Button("Reset", role: .destructive) {
                    if let id = view.projectStore.selectedProject?.id {
                        Task { try? await view.projectStore.resetSettingsToDefault(for: id) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This project's settings go back to Echo's defaults. Connections and identities stay.")
            }
            .confirmationDialog(
                "Duplicate Connection",
                isPresented: Binding(
                    get: { view.pendingDuplicateConnection != nil },
                    set: { if !$0 { view.pendingDuplicateConnection = nil } }
                ),
                titleVisibility: .visible,
                presenting: view.pendingDuplicateConnection
            ) { connection in
                Button("Duplicate with Bookmark History") { view.performDuplicate(connection, copyBookmarks: true) }
                Button("Duplicate Only Connection") { view.performDuplicate(connection, copyBookmarks: false) }
                Button("Cancel", role: .cancel) { view.pendingDuplicateConnection = nil }
            } message: { _ in
                Text("Do you want to copy the bookmark history into the duplicated connection?")
            }
    }
}
