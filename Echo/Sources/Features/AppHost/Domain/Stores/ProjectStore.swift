import Foundation
import Observation
import SwiftUI
import EchoSense

/// A modular store that manages project state and global settings.
/// Refactored from `EnvironmentState` to adhere to modular MVVM and under-500-line limits.
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
        self.globalSettings = try await repository.loadGlobalSettings()
        
        // Ensure a default project exists
        if projects.isEmpty {
            let defaultProject = Project(id: UUID(), name: "Default Project", isDefault: true)
            projects = [defaultProject]
            try await saveProjects(projects)
        }
        
        // Select initial project
        self.selectedProject = projects.first(where: { $0.isDefault }) ?? projects.first
    }
    
    func saveProjects(_ projects: [Project]) async throws {
        self.projects = projects
        try await repository.saveProjects(projects)
    }
    
    func saveGlobalSettings(_ settings: GlobalSettings) async throws {
        self.globalSettings = settings
        try await repository.saveGlobalSettings(settings)
    }
    
    func selectProject(_ project: Project?) {
        self.selectedProject = project
    }
    
    func createProject(name: String, colorHex: String, iconName: String?) async throws -> Project {
        let uniqueName = generateUniqueProjectName(for: name)
        let newProject = Project(id: UUID(), name: uniqueName, colorHex: colorHex, iconName: iconName, isDefault: false)
        projects.append(newProject)
        try await saveProjects(projects)
        return newProject
    }
    
    func updateProject(_ project: Project) async throws {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index] = project
        try await saveProjects(projects)
    }
    
    func saveProject(_ project: Project) async {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        }
        try? await repository.saveProject(project)
    }
    
    func deleteProject(_ project: Project) async throws {
        guard !project.isDefault else { return }
        
        projects.removeAll { $0.id == project.id }
        try await saveProjects(projects)
        
        if selectedProject?.id == project.id {
            selectedProject = projects.first(where: { $0.isDefault }) ?? projects.first
        }
    }
    
    func updateGlobalSettings(_ settings: GlobalSettings) async throws {
        self.globalSettings = settings
        try await repository.saveGlobalSettings(settings)
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
