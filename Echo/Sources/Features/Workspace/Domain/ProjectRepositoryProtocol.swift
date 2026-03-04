import Foundation
import Combine
import EchoSense

/// Protocol defining the contract for managing project data and persistence.
protocol ProjectRepositoryProtocol: Sendable {
    /// Loads all saved projects from persistence.
    func loadProjects() async throws -> [Project]
    
    /// Saves the current list of projects to persistence.
    func saveProjects(_ projects: [Project]) async throws
    
    /// Saves or updates a single project.
    func saveProject(_ project: Project) async throws
    
    /// Deletes a project from persistence.
    func deleteProject(_ project: Project) async throws
    
    /// Loads the global application settings.
    func loadGlobalSettings() async throws -> GlobalSettings
    
    /// Saves the global application settings.
    func saveGlobalSettings(_ settings: GlobalSettings) async throws
    
    /// Exports a specific project with optional associated data.
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
    ) async throws -> Data
    
    /// Imports a project from encrypted data.
    func importProject(from data: Data, password: String) async throws -> ProjectExportData
}
