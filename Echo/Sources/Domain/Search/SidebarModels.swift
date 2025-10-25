import Foundation
import SwiftUI

// MARK: - Sidebar Item Models

enum FolderCredentialMode: String, Codable, CaseIterable {
    case none
    case manual
    case identity
    case inherit

    var displayName: String {
        switch self {
        case .none: return "No Credentials"
        case .manual: return "Manual Credentials"
        case .identity: return "Link Identity"
        case .inherit: return "Inherit from Parent"
        }
    }
}

enum FolderKind: String, Codable, CaseIterable {
    case connections
    case identities

    var displayName: String {
        switch self {
        case .connections: return "Connections"
        case .identities: return "Identities"
        }
    }
}

enum SidebarItem: Identifiable, Hashable, Codable {
    case connection(SavedConnection)
    case folder(SavedFolder)

    var id: UUID {
        switch self {
        case .connection(let connection):
            return connection.id
        case .folder(let folder):
            return folder.id
        }
    }

    var name: String {
        switch self {
        case .connection(let connection):
            return connection.connectionName
        case .folder(let folder):
            return folder.name
        }
    }

    var isConnection: Bool {
        if case .connection = self { return true }
        return false
    }

    var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }

    var connection: SavedConnection? {
        if case .connection(let connection) = self { return connection }
        return nil
    }

    var folder: SavedFolder? {
        if case .folder(let folder) = self { return folder }
        return nil
    }
}

struct SavedFolder: Identifiable, Codable, Hashable, Sendable {
    static let defaultColorHex = "007AFF"

    var id: UUID = UUID()
    var projectID: UUID?
    var name: String
    var parentFolderID: UUID?
    var createdAt: Date
    var colorHex: String
    var kind: FolderKind = .connections
    var credentialMode: FolderCredentialMode = .none
    var identityID: UUID?
    var manualUsername: String?
    var manualKeychainIdentifier: String?
    var children: [SidebarItem] = []

    var connectionCount: Int {
        children.filter { $0.isConnection }.count
    }

    init(name: String, projectID: UUID? = nil, parentFolderID: UUID? = nil, colorHex: String = Self.defaultColorHex) {
        self.name = name
        self.projectID = projectID
        self.parentFolderID = parentFolderID
        self.createdAt = Date()
        self.colorHex = colorHex
    }

    // MARK: - Codable Support for Color

    private enum CodingKeys: String, CodingKey {
        case id, projectID, name, parentFolderID, createdAt, colorHex, kind, credentialMode, identityID, manualUsername, manualKeychainIdentifier, children
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectID = try container.decodeIfPresent(UUID.self, forKey: .projectID)
        name = try container.decode(String.self, forKey: .name)
        parentFolderID = try container.decodeIfPresent(UUID.self, forKey: .parentFolderID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        kind = try container.decodeIfPresent(FolderKind.self, forKey: .kind) ?? .connections
        credentialMode = try container.decodeIfPresent(FolderCredentialMode.self, forKey: .credentialMode) ?? .none
        identityID = try container.decodeIfPresent(UUID.self, forKey: .identityID)
        manualUsername = try container.decodeIfPresent(String.self, forKey: .manualUsername)
        manualKeychainIdentifier = try container.decodeIfPresent(String.self, forKey: .manualKeychainIdentifier)
        children = try container.decodeIfPresent([SidebarItem].self, forKey: .children) ?? []

        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? Self.defaultColorHex
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(projectID, forKey: .projectID)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(parentFolderID, forKey: .parentFolderID)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(kind, forKey: .kind)
        try container.encode(credentialMode, forKey: .credentialMode)
        try container.encodeIfPresent(identityID, forKey: .identityID)
        try container.encodeIfPresent(manualUsername, forKey: .manualUsername)
        try container.encodeIfPresent(manualKeychainIdentifier, forKey: .manualKeychainIdentifier)
        try container.encode(children, forKey: .children)
        try container.encode(colorHex, forKey: .colorHex)
    }
}

extension SavedFolder {
    nonisolated var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    mutating func updateColor(_ color: Color) {
        colorHex = color.toHex() ?? Self.defaultColorHex
    }
}
