import Foundation
@testable import Echo
import EchoSense

final class MockProjectRepository: ProjectRepositoryProtocol, @unchecked Sendable {
    // MARK: - In-Memory Storage

    var projects: [Project] = []
    var globalSettings: GlobalSettings = GlobalSettings()

    // MARK: - Call Tracking

    var loadProjectsCallCount = 0
    var saveProjectsCallCount = 0
    var saveProjectCallCount = 0
    var deleteProjectCallCount = 0
    var loadGlobalSettingsCallCount = 0
    var saveGlobalSettingsCallCount = 0
    var exportProjectCallCount = 0
    var importProjectCallCount = 0

    // MARK: - Error Injection

    var loadProjectsError: Error?
    var saveProjectsError: Error?
    var loadGlobalSettingsError: Error?
    var exportProjectError: Error?
    var importProjectResult: ProjectExportData?
    var importProjectError: Error?

    // MARK: - ProjectRepositoryProtocol

    func loadProjects() async throws -> [Project] {
        loadProjectsCallCount += 1
        if let error = loadProjectsError { throw error }
        return projects
    }

    func saveProjects(_ projects: [Project]) async throws {
        saveProjectsCallCount += 1
        if let error = saveProjectsError { throw error }
        self.projects = projects
    }

    func saveProject(_ project: Project) async throws {
        saveProjectCallCount += 1
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
    }

    func deleteProject(_ project: Project) async throws {
        deleteProjectCallCount += 1
        projects.removeAll { $0.id == project.id }
    }

    func loadGlobalSettings() async throws -> GlobalSettings {
        loadGlobalSettingsCallCount += 1
        if let error = loadGlobalSettingsError { throw error }
        return globalSettings
    }

    func saveGlobalSettings(_ settings: GlobalSettings) async throws {
        saveGlobalSettingsCallCount += 1
        self.globalSettings = settings
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
        exportProjectCallCount += 1
        if let error = exportProjectError { throw error }
        return Data()
    }

    func importProject(from data: Data, password: String) async throws -> ProjectExportData {
        importProjectCallCount += 1
        if let error = importProjectError { throw error }
        guard let result = importProjectResult else {
            throw NSError(domain: "MockProjectRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "No import result configured"])
        }
        return result
    }
}
