import Foundation
import SwiftUI
import Combine
import EchoSense

// MARK: - Project

struct Project: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var colorHex: String
    var iconName: String?
    var isDefault: Bool
    var isSyncEnabled: Bool

    // Project-specific settings
    var settings: ProjectSettings
    var bookmarks: [Bookmark]

    /// Per-project copy of all application settings. `nil` means the project
    /// has not been migrated yet — on first load the global defaults are copied in.
    var projectGlobalSettings: GlobalSettings?


    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        colorHex: String = "",
        iconName: String? = nil,
        isDefault: Bool = false,
        isSyncEnabled: Bool = false,
        settings: ProjectSettings = ProjectSettings(),
        bookmarks: [Bookmark] = [],
        projectGlobalSettings: GlobalSettings? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.colorHex = colorHex
        self.iconName = iconName
        self.isDefault = isDefault
        self.isSyncEnabled = isSyncEnabled
        self.settings = settings
        self.bookmarks = bookmarks
        self.projectGlobalSettings = projectGlobalSettings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? ""
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        isSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSyncEnabled) ?? false
        settings = try container.decodeIfPresent(ProjectSettings.self, forKey: .settings) ?? ProjectSettings()
        bookmarks = try container.decodeIfPresent([Bookmark].self, forKey: .bookmarks) ?? []
        projectGlobalSettings = try container.decodeIfPresent(GlobalSettings.self, forKey: .projectGlobalSettings)
    }

    static let defaultProject = Project(
        name: "Default",
        colorHex: "007AFF",
        isDefault: true,
        bookmarks: []
    )
}

extension Project {
    nonisolated var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    mutating func updateColor(_ color: Color) {
        colorHex = color.toHex() ?? ""
    }

    var toolbarIcon: ToolbarIcon {
        guard let iconName, !iconName.isEmpty else {
            return .system("folder.fill")
        }

        #if canImport(AppKit)
        if NSImage(named: iconName) != nil {
            return .asset(iconName, isTemplate: true)
        }
        #endif

        return .system(iconName)
    }

    var iconRenderInfo: (image: Image, isSystemSymbol: Bool) {
        guard let iconName, !iconName.isEmpty else {
            return (Image(systemName: "folder.badge.gearshape"), true)
        }

        #if canImport(AppKit)
        if NSImage(named: iconName) != nil {
            return (Image(iconName), false)
        }

        if NSImage(systemSymbolName: iconName, accessibilityDescription: nil) != nil {
            return (Image(systemName: iconName), true)
        }
        #endif

        return (Image(systemName: "folder.badge.gearshape"), true)
    }
}

// MARK: - Project Export/Import Models

struct ProjectExportData: Codable, Sendable {
    let project: Project
    let connections: [SavedConnection]
    let identities: [SavedIdentity]
    let folders: [SavedFolder]
    let globalSettings: GlobalSettings?
    let clipboardHistory: [ClipboardHistoryStore.Entry]?
    let autocompleteHistory: SQLAutoCompletionHistoryStore.Snapshot?
    let diagramCaches: [DiagramCachePayload]?
    let bookmarks: [Bookmark]
    let exportedAt: Date
    let version: String

    init(
        project: Project,
        connections: [SavedConnection],
        identities: [SavedIdentity],
        folders: [SavedFolder],
        globalSettings: GlobalSettings?,
        clipboardHistory: [ClipboardHistoryStore.Entry]? = nil,
        autocompleteHistory: SQLAutoCompletionHistoryStore.Snapshot? = nil,
        diagramCaches: [DiagramCachePayload]? = nil,
        bookmarks: [Bookmark] = [],
        exportedAt: Date = Date(),
        version: String = "1.0"
    ) {
        self.project = project
        self.connections = connections
        self.identities = identities
        self.folders = folders
        self.globalSettings = globalSettings
        self.clipboardHistory = clipboardHistory
        self.autocompleteHistory = autocompleteHistory
        self.diagramCaches = diagramCaches
        self.bookmarks = bookmarks
        self.exportedAt = exportedAt
        self.version = version
    }
}
