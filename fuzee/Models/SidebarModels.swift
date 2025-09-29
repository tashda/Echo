import Foundation
import SwiftUI

// MARK: - Sidebar Item Models

enum FolderCredentialMode: String, Codable, CaseIterable {
    case none
    case identity
    case inherit

    var displayName: String {
        switch self {
        case .none: return "No Credentials"
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

struct SavedFolder: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var parentFolderID: UUID?
    var createdAt: Date
    var color: Color
    var kind: FolderKind = .connections
    var credentialMode: FolderCredentialMode = .none
    var identityID: UUID?
    var children: [SidebarItem] = []

    var connectionCount: Int {
        children.filter { $0.isConnection }.count
    }

    init(name: String, parentFolderID: UUID? = nil, color: Color = .blue) {
        self.name = name
        self.parentFolderID = parentFolderID
        self.createdAt = Date()
        self.color = color
    }

    // MARK: - Codable Support for Color

    private enum CodingKeys: String, CodingKey {
        case id, name, parentFolderID, createdAt, colorHex, kind, credentialMode, identityID, children
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        parentFolderID = try container.decodeIfPresent(UUID.self, forKey: .parentFolderID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        kind = try container.decodeIfPresent(FolderKind.self, forKey: .kind) ?? .connections
        credentialMode = try container.decodeIfPresent(FolderCredentialMode.self, forKey: .credentialMode) ?? .none
        identityID = try container.decodeIfPresent(UUID.self, forKey: .identityID)
        children = try container.decodeIfPresent([SidebarItem].self, forKey: .children) ?? []

        if let colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) {
            color = Color(hex: colorHex) ?? .blue
        } else {
            color = .blue
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(parentFolderID, forKey: .parentFolderID)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(kind, forKey: .kind)
        try container.encode(credentialMode, forKey: .credentialMode)
        try container.encodeIfPresent(identityID, forKey: .identityID)
        try container.encode(children, forKey: .children)
        try container.encodeIfPresent(color.toHex(), forKey: .colorHex)
    }
}
