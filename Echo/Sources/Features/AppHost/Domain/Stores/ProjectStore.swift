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
        
        // Find folders that are parents of selected connections/identities
        let selectedFolderIDs = Set(sourceConnections.compactMap(\.folderID) + sourceIdentities.compactMap(\.folderID))
        let sourceFolders = connectionStore.folders.filter { selectedFolderIDs.contains($0.id) || $0.projectID == sourceProject.id && selectedFolderIDs.contains($0.parentFolderID ?? UUID()) }
        // Note: For a truly robust implementation we'd need to recursive-walk the folders.
        // For now, let's just grab the folders explicitly referenced.

        for var conn in sourceConnections {
            conn.id = UUID()
            conn.projectID = targetProjectID
            connectionStore.connections.append(conn)
        }

        for var identity in sourceIdentities {
            identity.id = UUID()
            identity.projectID = targetProjectID
            connectionStore.identities.append(identity)
        }

        // We only copy folders if they don't exist yet or we just copy them as new instances
        // To avoid duplicates if merging, we could check names, but project items are isolated by ID.
        for var folder in sourceFolders {
            folder.id = UUID()
            folder.projectID = targetProjectID
            connectionStore.folders.append(folder)
        }

        try await saveProjects(projects)
        try await repository.saveGlobalSettings(globalSettings)
        try await connectionStore.saveConnections()
        try await connectionStore.saveIdentities()
        try await connectionStore.saveFolders()
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
        folders: [SavedFolder],
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
