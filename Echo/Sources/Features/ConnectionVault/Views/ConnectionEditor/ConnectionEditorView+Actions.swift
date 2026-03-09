import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

extension ConnectionEditorView {
    func handleSave(action: SaveAction) {
        cancelActiveTest()

        let generatedLogo = generateConnectionLogo(
            databaseType: selectedDatabaseType,
            color: currentColor
        )

        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDatabase = database.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDomain = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedPort = selectedDatabaseType == .sqlite ? 0 : port
        let sanitizedDatabase = selectedDatabaseType == .sqlite ? "" : trimmedDatabase
        let sanitizedUsername = selectedDatabaseType == .sqlite ? "" : trimmedUsername
        let sanitizedAuthenticationMethod: DatabaseAuthenticationMethod = {
            if selectedDatabaseType == .sqlite {
                return .sqlPassword
            }
            let supported = selectedDatabaseType.supportedAuthenticationMethods
            return supported.contains(authenticationMethod) ? authenticationMethod : selectedDatabaseType.defaultAuthenticationMethod
        }()

        var sanitizedCredentialSource: CredentialSource = selectedDatabaseType == .sqlite ? .manual : credentialSource
        if !sanitizedAuthenticationMethod.supportsExternalCredentials {
            sanitizedCredentialSource = .manual
        }

        let sanitizedIdentityID = selectedDatabaseType == .sqlite ? nil : identityID
        let sanitizedUseTLS = selectedDatabaseType == .sqlite ? false : useTLS
        let sanitizedDomain = selectedDatabaseType == .sqlite ? "" : trimmedDomain

        let connection = SavedConnection(
            id: originalConnection?.id ?? UUID(),
            projectID: originalConnection?.projectID ?? projectStore.selectedProject?.id,
            connectionName: connectionName.trimmingCharacters(in: .whitespacesAndNewlines),
            host: trimmedHost,
            port: sanitizedPort,
            database: sanitizedDatabase,
            username: sanitizedUsername,
            authenticationMethod: sanitizedAuthenticationMethod,
            domain: sanitizedDomain,
            credentialSource: sanitizedCredentialSource,
            identityID: sanitizedIdentityID,
            keychainIdentifier: originalConnection?.keychainIdentifier,
            folderID: folderID,
            useTLS: sanitizedUseTLS,
            databaseType: selectedDatabaseType,
            serverVersion: originalConnection?.serverVersion,
            colorHex: colorHex,
            logo: generatedLogo,
            cachedStructure: originalConnection?.cachedStructure,
            cachedStructureUpdatedAt: originalConnection?.cachedStructureUpdatedAt
        )

        let passwordToPersist: String?
        if selectedDatabaseType == .sqlite {
            passwordToPersist = nil
        } else if sanitizedCredentialSource == .manual && passwordDirty && !password.isEmpty {
            passwordToPersist = password
        } else {
            passwordToPersist = nil
        }
        onSave(connection, passwordToPersist, action)
        // Note: dismiss is handled by the caller after the save completes
    }

    func generateConnectionLogo(databaseType: DatabaseType, color: Color) -> Data? {
#if os(macOS)
        let size: CGFloat = 64
        let image = NSImage(size: NSSize(width: size, height: size))

        image.lockFocus()
        defer { image.unlockFocus() }

        // Draw background with color
        let backgroundColor = NSColor(color.opacity(0.15))
        backgroundColor.setFill()
        let backgroundPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: 12, yRadius: 12)
        backgroundPath.fill()

        // Draw database icon
        if let iconImage = NSImage(named: databaseType.iconName) ?? NSImage(systemSymbolName: databaseType.iconName, accessibilityDescription: nil) {
            let iconSize: CGFloat = 32
            let iconRect = NSRect(
                x: (size - iconSize) / 2,
                y: (size - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )

            iconImage.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)

            // Tint the icon with the color
            NSColor(color).setFill()
            iconRect.fill(using: .sourceAtop)
        }

        // Convert to PNG
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }

        return pngData
#else
        return nil
#endif
    }

    func handleTestButton() {
        if isTestingConnection {
            cancelActiveTest()
        } else {
            startConnectionTest()
        }
    }

#if os(macOS)
    func browseForSQLiteFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        let allowedTypes = ["sqlite", "sqlite3", "db", "db3"].compactMap { UTType(filenameExtension: $0) }
        if !allowedTypes.isEmpty {
            panel.allowedContentTypes = allowedTypes
        }
        panel.message = "Select an existing SQLite database file."
        if panel.runModal() == .OK, let url = panel.url {
            host = url.path
        }
    }
#endif

    func folderDisplayName(_ folder: SavedFolder) -> String {
        var components: [String] = [folder.name]
        var current = folder
        var visited: Set<UUID> = [folder.id]

        while let parentID = current.parentFolderID,
              !visited.contains(parentID),
              let parent = connectionStore.folders.first(where: { $0.id == parentID }) {
            components.append(parent.name)
            current = parent
            visited.insert(parent.id)
        }

        return components.reversed().joined(separator: " / ")
    }
}
