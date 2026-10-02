import Foundation
import SwiftUI

/// What a folder holds: connections or identities.
enum FolderKind: String, Codable, CaseIterable, Sendable {
    case connections
    case identities

    var displayName: String {
        switch self {
        case .connections: return "Connections"
        case .identities: return "Identities"
        }
    }
}

/// A folder that organises connections (or identities) inside a project.
///
/// Folders are organisation only: they hold no credentials. Files written before
/// round MC may still carry `credentialMode`, `identityID`, `manualUsername`,
/// `manualKeychainIdentifier` and `children`; those keys are ignored when decoding.
struct SavedFolder: Identifiable, Codable, Hashable, Sendable {
    static let defaultColorHex = "007AFF"

    static let defaultIcon = "folder"

    var id: UUID = UUID()
    var projectID: UUID?
    var name: String
    var folderDescription: String?
    var icon: String = SavedFolder.defaultIcon
    /// The folder this one is nested in, or nil for the top level.
    var parentFolderID: UUID?
    var createdAt: Date
    var colorHex: String
    var kind: FolderKind = .connections

    init(
        id: UUID = UUID(),
        name: String,
        folderDescription: String? = nil,
        projectID: UUID? = nil,
        parentFolderID: UUID? = nil,
        colorHex: String = Self.defaultColorHex,
        icon: String = Self.defaultIcon,
        kind: FolderKind = .connections,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.folderDescription = folderDescription
        self.projectID = projectID
        self.parentFolderID = parentFolderID
        self.colorHex = colorHex
        self.icon = icon
        self.kind = kind
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, projectID, name, folderDescription, icon, parentFolderID, createdAt, colorHex, kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectID = try container.decodeIfPresent(UUID.self, forKey: .projectID)
        name = try container.decode(String.self, forKey: .name)
        folderDescription = try container.decodeIfPresent(String.self, forKey: .folderDescription)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? SavedFolder.defaultIcon
        parentFolderID = try container.decodeIfPresent(UUID.self, forKey: .parentFolderID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        kind = try container.decodeIfPresent(FolderKind.self, forKey: .kind) ?? .connections
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? Self.defaultColorHex
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(projectID, forKey: .projectID)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(folderDescription, forKey: .folderDescription)
        try container.encode(icon, forKey: .icon)
        try container.encodeIfPresent(parentFolderID, forKey: .parentFolderID)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(kind, forKey: .kind)
        try container.encode(colorHex, forKey: .colorHex)
    }
}

extension SavedFolder {
    var displayName: String { name }

    nonisolated var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    mutating func updateColor(_ color: Color) {
        colorHex = color.toHex() ?? Self.defaultColorHex
    }
}
