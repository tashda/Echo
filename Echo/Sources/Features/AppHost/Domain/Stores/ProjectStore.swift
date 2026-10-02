import Foundation
import Observation
import SwiftUI
import EchoSense

/// A modular store that manages project state and global settings.
/// Settings are stored per-project — switching projects updates `globalSettings`.
@Observable @MainActor
final class ProjectStore {
    // MARK: - State
    var projects: [Project] = []
    var selectedProject: Project?
    var globalSettings: GlobalSettings = GlobalSettings()

    // MARK: - Dependencies
    private let repository: any ProjectRepositoryProtocol

    // MARK: - Initialization
    init(repository: any ProjectRepositoryProtocol = ProjectRepository()) {
        self.repository = repository
    }

    // MARK: - Public API

    func load() async throws {
        self.projects = try await repository.loadProjects()
        let loadedGlobalSettings = try await repository.loadGlobalSettings()

        // Migrate projects that don't have per-project settings yet
        var needsSave = false
        for i in projects.indices {
            if projects[i].projectGlobalSettings == nil {
                projects[i].projectGlobalSettings = loadedGlobalSettings
                needsSave = true
            }
        }

        // Ensure a default project exists
        if projects.isEmpty {
            let defaultProject = Project(
                id: UUID(),
                name: "Default Project",
                isDefault: true,
                projectGlobalSettings: loadedGlobalSettings
            )
            projects = [defaultProject]
            needsSave = true
        }

        if needsSave {
            try await repository.saveProjects(projects)
        }

        // Select initial project and load its settings
        self.selectedProject = projects.first(where: { $0.isDefault }) ?? projects.first
        self.globalSettings = selectedProject?.projectGlobalSettings ?? loadedGlobalSettings
    }

    func saveProjects(_ projects: [Project]) async throws {
        self.projects = projects
        try await repository.saveProjects(projects)
    }

    /// Callback for sync engine — fires when settings change for a project.
    var onSettingsChanged: ((UUID) -> Void)?

    func saveGlobalSettings(_ settings: GlobalSettings) async throws {
        self.globalSettings = settings
        // Update active project in memory
        if let project = selectedProject,
           let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx].projectGlobalSettings = settings
            selectedProject = projects[idx]

            // Save projects list (includes this project's settings) asynchronously
            let procs = projects
            Task.detached(priority: .background) {
                try? await self.repository.saveProjects(procs)
            }

            // Notify sync engine
            onSettingsChanged?(project.id)
        }

        // Also update global_settings.json as fallback asynchronously
        Task.detached(priority: .background) {
            try? await self.repository.saveGlobalSettings(settings)
        }
    }

    func selectProject(_ project: Project?) {
        self.selectedProject = project
        if let settings = project?.projectGlobalSettings {
            self.globalSettings = settings
        }
    }

    func createProject(name: String, colorHex: String, iconName: String?) async throws -> Project {
        let uniqueName = generateUniqueProjectName(for: name)
        let newProject = Project(
            id: UUID(),
            name: uniqueName,
            colorHex: colorHex,
            iconName: iconName,
            isDefault: false,
            projectGlobalSettings: GlobalSettings()
        )
        projects.append(newProject)
        try await saveProjects(projects)
        return newProject
    }

    func updateProject(_ project: Project) async throws {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index] = project
        if selectedProject?.id == project.id {
            selectedProject = projects[index]
            if let settings = projects[index].projectGlobalSettings {
                globalSettings = settings
            }
        }
        try await saveProjects(projects)
    }

    func saveProject(_ project: Project) async {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            if selectedProject?.id == project.id {
                selectedProject = projects[index]
            }
        }
        try? await repository.saveProject(project)
    }

    func deleteProject(_ project: Project) async throws {
        guard !project.isDefault else { return }

        projects.removeAll { $0.id == project.id }
        try await saveProjects(projects)

        if selectedProject?.id == project.id {
            let newSelection = projects.first(where: { $0.isDefault }) ?? projects.first
            selectProject(newSelection)
        }
    }

    func updateGlobalSettings(_ settings: GlobalSettings) async throws {
        try await saveGlobalSettings(settings)
    }

    /// Import settings and resources from another project into the target project.
    func importProjectResources(
        from sourceProject: Project,
        into targetProjectID: UUID,
        connectionStore: ConnectionStore,
        merge: Bool,
        includeSettings: Bool,
        connectionIDs: Set<UUID>,
        identityIDs: Set<UUID>
    ) async throws {
        guard let targetIdx = projects.firstIndex(where: { $0.id == targetProjectID }) else { return }

        // 1. Update Global Settings if requested
        if includeSettings, let sourceSettings = sourceProject.projectGlobalSettings {
            projects[targetIdx].projectGlobalSettings = sourceSettings
            if selectedProject?.id == targetProjectID {
                globalSettings = sourceSettings
            }
        }
        
        projects[targetIdx].updatedAt = Date()
        if selectedProject?.id == targetProjectID {
            selectedProject = projects[targetIdx]
        }

        // 2. Handle Connections, Identities, and Folders
        if !merge {
            // Clear target resources first
            connectionStore.connections.removeAll { $0.projectID == targetProjectID }
            connectionStore.identities.removeAll { $0.projectID == targetProjectID }
            connectionStore.folders.removeAll { $0.projectID == targetProjectID }
        }

        let sourceConnections = connectionStore.connections.filter { connectionIDs.contains($0.id) }
        let sourceIdentities = connectionStore.identities.filter { identityIDs.contains($0.id) }

        // Copy the folders the selected connections/identities are filed in, with their
        // ancestors, as new folders in the target project; items keep their place.
        let folderIDMap = Self.copyFolders(
            containing: sourceConnections.compactMap(\.folderID) + sourceIdentities.compactMap(\.folderID),
            into: targetProjectID,
            connectionStore: connectionStore
        )

        for var conn in sourceConnections {
            conn.id = UUID()
            conn.projectID = targetProjectID
            conn.folderID = conn.folderID.flatMap { folderIDMap[$0] }
            connectionStore.connections.append(conn)
        }

        for var identity in sourceIdentities {
            identity.id = UUID()
            identity.projectID = targetProjectID
            identity.folderID = identity.folderID.flatMap { folderIDMap[$0] }
            connectionStore.identities.append(identity)
        }

        try await saveProjects(projects)
        try await repository.saveGlobalSettings(globalSettings)
        try await connectionStore.saveConnections()
        try await connectionStore.saveIdentities()
        try await connectionStore.saveFolders()
    }

    /// Appends copies (new ids, target project) of the given folders and all their ancestors
    /// to `connectionStore.folders`, and returns old id → new id.
    private static func copyFolders(
        containing folderIDs: [UUID],
        into targetProjectID: UUID,
        connectionStore: ConnectionStore
    ) -> [UUID: UUID] {
        var needed: [SavedFolder] = []
        var seen: Set<UUID> = []
        for folderID in folderIDs {
            for folder in connectionStore.folderPath(to: folderID) where !seen.contains(folder.id) {
                seen.insert(folder.id)
                needed.append(folder)
            }
        }
        var map: [UUID: UUID] = [:]
        for folder in needed { map[folder.id] = UUID() }
        for var folder in needed {
            guard let newID = map[folder.id] else { continue }
            folder.id = newID
            folder.projectID = targetProjectID
            folder.parentFolderID = folder.parentFolderID.flatMap { map[$0] }
            connectionStore.folders.append(folder)
        }
        return map
    }

    /// Reset a project's settings to factory defaults.
    func resetSettingsToDefault(for projectID: UUID) async throws {
        guard let idx = projects.firstIndex(where: { $0.id == projectID }) else { return }
        let defaults = GlobalSettings()
        projects[idx].projectGlobalSettings = defaults
        projects[idx].updatedAt = Date()
        if selectedProject?.id == projectID {
            selectedProject = projects[idx]
            globalSettings = defaults
        }
        try await saveProjects(projects)
        try await repository.saveGlobalSettings(globalSettings)
    }

    func exportProject(
        _ project: Project,
        connections: [SavedConnection],
        identities: [SavedIdentity],
        folders: [SavedFolder] = [],
        globalSettings: GlobalSettings?,
        clipboardHistory: [ClipboardHistoryStore.Entry]?,
        autocompleteHistory: SQLAutoCompletionHistoryStore.Snapshot?,
        diagramCaches: [DiagramCachePayload]?,
        password: String
    ) async throws -> Data {
        try await repository.exportProject(
            project,
            connections: connections,
            identities: identities,
            folders: folders,
            globalSettings: globalSettings,
            clipboardHistory: clipboardHistory,
            autocompleteHistory: autocompleteHistory,
            diagramCaches: diagramCaches,
            password: password
        )
    }

    func importProject(from data: Data, password: String) async throws -> ProjectExportData {
        try await repository.importProject(from: data, password: password)
    }

    // MARK: - Helpers

    private func generateUniqueProjectName(for name: String) -> String {
        let base = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Project" : name
        var attempt = base
        var counter = 2
        while projects.contains(where: { $0.name == attempt }) {
            attempt = "\(base) \(counter)"
            counter += 1
        }
        return attempt
    }
}
