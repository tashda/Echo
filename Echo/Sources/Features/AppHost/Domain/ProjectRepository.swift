import Foundation
import Combine
import EchoSense

/// Implementation of the `ProjectRepositoryProtocol` using `ProjectDiskStore` for persistence.
final class ProjectRepository: ProjectRepositoryProtocol {
    private let diskStore: ProjectDiskStore
    
    init(diskStore: ProjectDiskStore = ProjectDiskStore()) {
        self.diskStore = diskStore
    }
    
    func loadProjects() async throws -> [Project] {
        try await diskStore.load()
    }
    
    func saveProjects(_ projects: [Project]) async throws {
        try await diskStore.save(projects)
    }

    func saveProject(_ project: Project) async throws {
        var current = try await loadProjects()
        if let index = current.firstIndex(where: { $0.id == project.id }) {
            current[index] = project
        } else {
            current.append(project)
        }
        try await saveProjects(current)
    }

    func deleteProject(_ project: Project) async throws {
        var current = try await loadProjects()
        current.removeAll { $0.id == project.id }
        try await saveProjects(current)
    }

    
    func loadGlobalSettings() async throws -> GlobalSettings {
        try await diskStore.loadGlobalSettings()
    }
    
    func saveGlobalSettings(_ settings: GlobalSettings) async throws {
        try await diskStore.saveGlobalSettings(settings)
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
        try await diskStore.exportProject(
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
        try await diskStore.importProject(from: data, password: password)
    }
}
