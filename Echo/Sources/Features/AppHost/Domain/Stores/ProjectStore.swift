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
        // Save to active project
        if let project = selectedProject,
           let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx].projectGlobalSettings = settings
            selectedProject = projects[idx]
            try await repository.saveProjects(projects)
        }
        // Also keep global_settings.json as fallback/template
        try await repository.saveGlobalSettings(settings)
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

    /// Import settings from another project into the target project.
    func importSettings(from sourceProject: Project, into targetProjectID: UUID) async throws {
        guard let sourceSettings = sourceProject.projectGlobalSettings,
              let idx = projects.firstIndex(where: { $0.id == targetProjectID }) else { return }
        projects[idx].projectGlobalSettings = sourceSettings
        projects[idx].updatedAt = Date()
        if selectedProject?.id == targetProjectID {
            selectedProject = projects[idx]
            globalSettings = sourceSettings
        }
        try await saveProjects(projects)
        try await repository.saveGlobalSettings(globalSettings)
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
