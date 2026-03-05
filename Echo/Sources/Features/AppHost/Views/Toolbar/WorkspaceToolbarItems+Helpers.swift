import SwiftUI
import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import EchoSense

extension WorkspaceToolbarItems {

    // MARK: - Session Helpers

    internal var canOpenNewTab: Bool {
        activeSession != nil
    }

    internal var activeSession: ConnectionSession? {
        if let connection = navigationStore.navigationState.selectedConnection,
           let session = environmentState.sessionCoordinator.sessionForConnection(connection.id) {
            return session
        }
        return environmentState.sessionCoordinator.activeSession ?? environmentState.sessionCoordinator.activeSessions.first
    }

    internal func availableDatabases(in session: ConnectionSession) -> [DatabaseInfo]? {
        if let structure = session.databaseStructure {
            return structure.databases
        }
        if let cached = session.connection.cachedStructure {
            return cached.databases
        }
        return nil
    }

    internal func selectDatabase(_ database: String, in session: ConnectionSession) {
        Task {
            await environmentState.loadSchemaForDatabase(database, connectionSession: session)
            await MainActor.run {
                navigationStore.navigationState.selectDatabase(database)
            }
        }
    }

    internal func displayName(for connection: SavedConnection) -> String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        let hostTrimmed = connection.host.trimmingCharacters(in: .whitespacesAndNewlines)
        return hostTrimmed.isEmpty ? "Untitled Connection" : hostTrimmed
    }

    // MARK: - Title Helpers

    internal var currentServerTitle: String {
        if let connection = navigationStore.navigationState.selectedConnection {
            let display = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            return display.isEmpty ? connection.host : display
        }
        return "Server"
    }

    internal var currentDatabaseTitle: String {
        navigationStore.navigationState.selectedDatabase ?? "Database"
    }

    // MARK: - Icon Helpers

    internal var projectIcon: ToolbarIcon { .system("folder.badge.person.crop") }

    internal var currentServerIcon: ToolbarIcon {
        if let connection = navigationStore.navigationState.selectedConnection {
            return connectionIcon(for: connection)
        }
        return .system("externaldrive")
    }

    internal func connectionIcon(for connection: SavedConnection) -> ToolbarIcon {
        let assetName = connection.databaseType.iconName
        if hasImage(named: assetName) {
            return .asset(assetName, isTemplate: false)
        }
        return .system("externaldrive")
    }

    internal func databaseToolbarIcon(isSelected: Bool) -> ToolbarIcon {
        let assetName = isSelected ? "database.check.outlined" : "database.outlined"
        if hasImage(named: assetName) {
            return .asset(assetName, isTemplate: false)
        }
        let fallbackName = isSelected ? "checkmark.circle" : "cylinder.split.1x2"
        return .system(fallbackName)
    }

    internal var databaseMenuIcon: ToolbarIcon {
        if hasImage(named: "database.outlined") {
            return .asset("database.outlined", isTemplate: false)
        }
        return .system("cylinder")
    }

    // MARK: - View Builders

    @ViewBuilder
    internal func toolbarButtonLabel(icon: ToolbarIcon, title: String) -> some View {
        HStack(spacing: 8) {
            toolbarIconView(icon)
            Text(title)
                .font(TypographyTokens.standard.weight(.regular))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, SpacingTokens.xxs2)
        .padding(.vertical, SpacingTokens.xxs)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    internal func menuRow(icon: ToolbarIcon, title: String, isSelected: Bool = false) -> some View {
        HStack(spacing: 8) {
            toolbarIconView(icon)
            Text(title)
                .font(TypographyTokens.standard.weight(.regular))
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(TypographyTokens.caption2.weight(.semibold))
            }
        }
    }

    @ViewBuilder
    internal func toolbarIconView(_ icon: ToolbarIcon) -> some View {
        icon.image
            .renderingMode(icon.isTemplate ? .template : .original)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 14, height: 14)
            .cornerRadius(icon.isTemplate ? 0 : 3)
    }

    // MARK: - Image Detection

    internal func hasImage(named name: String) -> Bool {
        #if canImport(AppKit)
        return NSImage(named: name) != nil
        #elseif canImport(UIKit)
        return UIImage(named: name) != nil
        #else
        return false
        #endif
    }
}
