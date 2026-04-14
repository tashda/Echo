import Foundation
import SwiftUI

// MARK: - Navigation State

@Observable
final class NavigationState {
    var selectedProject: Project?
    var selectedFolder: SavedFolder?
    var selectedConnection: SavedConnection?
    var selectedDatabase: String?

    // Navigation breadcrumb levels
    var breadcrumbs: [NavigationLevel] {
        var levels: [NavigationLevel] = []

        if let project = selectedProject {
            levels.append(.project(project))
        }

        if let folder = selectedFolder {
            levels.append(.folder(folder))
        } else if let connection = selectedConnection {
            levels.append(.connection(connection))
        }

        if let database = selectedDatabase, selectedConnection != nil {
            levels.append(.database(database))
        }

        return levels
    }

    func reset() {
        selectedFolder = nil
        selectedConnection = nil
        selectedDatabase = nil
    }

    func selectProject(_ project: Project) {
        selectedProject = project
        reset()
    }

    func selectFolder(_ folder: SavedFolder) {
        selectedFolder = folder
        selectedConnection = nil
        selectedDatabase = nil
    }

    func selectConnection(_ connection: SavedConnection) {
        selectedConnection = connection
        selectedFolder = nil
        selectedDatabase = nil
    }

    func selectDatabase(_ database: String) {
        selectedDatabase = database
    }

    func navigateBack() {
        if selectedDatabase != nil {
            selectedDatabase = nil
        } else if selectedConnection != nil {
            selectedConnection = nil
        } else if selectedFolder != nil {
            selectedFolder = nil
        }
    }
}

// MARK: - Navigation Level

enum NavigationLevel: Identifiable, Hashable {
    case project(Project)
    case folder(SavedFolder)
    case connection(SavedConnection)
    case database(String)

    var id: String {
        switch self {
        case .project(let project):
            return "project-\(project.id)"
        case .folder(let folder):
            return "folder-\(folder.id)"
        case .connection(let connection):
            return "connection-\(connection.id)"
        case .database(let name):
            return "database-\(name)"
        }
    }

    var displayName: String {
        switch self {
        case .project(let project):
            return project.name
        case .folder(let folder):
            return folder.name
        case .connection(let connection):
            return connection.connectionName.isEmpty ? connection.host : connection.connectionName
        case .database(let name):
            return name
        }
    }

    var icon: String {
        switch self {
        case .project:
            return "folder.badge.gearshape"
        case .folder:
            return "folder.fill"
        case .connection(let connection):
            return connection.databaseType.iconName
        case .database:
            return "cylinder.fill"
        }
    }

    @MainActor var color: Color? {
        switch self {
        case .project:
            return nil
        case .folder(let folder):
            return folder.color
        case .connection(let connection):
            return connection.color
        case .database:
            return nil
        }
    }
}
