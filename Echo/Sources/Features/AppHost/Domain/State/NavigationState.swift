import Foundation
import SwiftUI

// MARK: - Navigation State

@Observable
final class NavigationState {
    var selectedProject: Project?
    var selectedConnection: SavedConnection?
    var selectedDatabase: String?

    // Navigation breadcrumb levels
    var breadcrumbs: [NavigationLevel] {
        var levels: [NavigationLevel] = []

        if let project = selectedProject {
            levels.append(.project(project))
        }

        if let connection = selectedConnection {
            levels.append(.connection(connection))
        }

        if let database = selectedDatabase, selectedConnection != nil {
            levels.append(.database(database))
        }

        return levels
    }

    func reset() {
        selectedConnection = nil
        selectedDatabase = nil
    }

    func selectProject(_ project: Project) {
        selectedProject = project
        reset()
    }

    func selectConnection(_ connection: SavedConnection) {
        selectedConnection = connection
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
        }
    }
}

// MARK: - Navigation Level

enum NavigationLevel: Identifiable, Hashable {
    case project(Project)
    case connection(SavedConnection)
    case database(String)

    var id: String {
        switch self {
        case .project(let project):
            return "project-\(project.id)"
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
        case .connection(let connection):
            return connection.color
        case .database:
            return nil
        }
    }
}
