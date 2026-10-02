import Foundation
import CryptoKit
import EchoSense
import EchoLocalStorage

actor ProjectDiskStore {
    func load() async throws -> [Project] {
        try await LocalConfigurationArchive.load(Project.self, collection: "projects", filename: "projects.json")
    }

    func save(_ projects: [Project]) async throws {
        let snapshots = try await Self.snapshots(projects)
        try await LocalConfigurationArchive.storage.replaceCollections(snapshots,
            syncProjects: Set(projects.filter(\.isSyncEnabled).map { $0.id.uuidString }))
    }

    @MainActor static func snapshots(_ projects: [Project]) throws -> [LocalCollectionSnapshot] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let records = try projects.enumerated().map { position, project in
            LocalRecord(collection: "projects", id: project.id.uuidString, group: project.id.uuidString,
                        payload: try encoder.encode(project), position: position)
        }
        let bookmarks = try projects.flatMap { project in
            try project.bookmarks.enumerated().map { position, bookmark in
                LocalRecord(collection: "bookmarks", id: bookmark.id.uuidString, group: project.id.uuidString,
                    payload: try encoder.encode(bookmark), position: position)
            }
        }
        let settings = try projects.compactMap { project -> LocalRecord? in
            guard let settings = project.projectGlobalSettings else { return nil }
            return LocalRecord(collection: "settings", id: SyncAdapter().settingsDocumentID(for: project.id).uuidString,
                group: project.id.uuidString, payload: try encoder.encode(settings))
        }
        return [.init(collection: "projects", records: records), .init(collection: "bookmarks", records: bookmarks),
                .init(collection: "project-settings", records: settings.map {
                    LocalRecord(collection: "project-settings", id: $0.id, group: $0.group, payload: $0.payload)
                })]
    }

    func loadGlobalSettings() async throws -> GlobalSettings {
        let storage = LocalConfigurationArchive.storage
        let legacy = LocalConfigurationArchive.legacyURL("global_settings.json")
        if !(try await storage.hasMigration("global-settings")) {
            if FileManager.default.fileExists(atPath: legacy.path) {
                let data = try Data(contentsOf: legacy)
                let settings = try await MainActor.run { try JSONDecoder().decode(GlobalSettings.self, from: data) }
                try await saveGlobalSettings(settings)
                _ = try await storage.read(collection: "settings", id: "global")
                try await storage.finishMigration("global-settings")
                try FileManager.default.removeItem(at: legacy)
            } else {
                try await storage.finishMigration("global-settings")
            }
        }
        guard let data = try await storage.read(collection: "settings", id: "global") else {
            return await MainActor.run { GlobalSettings() }
        }
        return try await MainActor.run { try JSONDecoder().decode(GlobalSettings.self, from: data) }
    }

    func saveGlobalSettings(_ settings: GlobalSettings) async throws {
        let data = try await MainActor.run { try LocalRecordEncoding.encode(settings) }
        try await LocalConfigurationArchive.storage.write(
            LocalRecord(collection: "settings", id: "global", payload: data)
        )
    }

    // MARK: - Export/Import with Encryption

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
        let jsonData = try await MainActor.run { () -> Data in
            let exportData = ProjectExportData(
                project: project,
                connections: connections,
                identities: identities,
                folders: folders,
                globalSettings: globalSettings,
                clipboardHistory: clipboardHistory,
                autocompleteHistory: autocompleteHistory,
                diagramCaches: diagramCaches,
                bookmarks: project.bookmarks
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(exportData)
        }

        return try encryptData(jsonData, password: password)
    }

    func importProject(from data: Data, password: String) async throws -> ProjectExportData {
        // Decrypt the data
        let decryptedData = try decryptData(data, password: password)

        return try await MainActor.run {
            try JSONDecoder().decode(ProjectExportData.self, from: decryptedData)
        }
    }

    // MARK: - Encryption Helpers

    private func encryptData(_ data: Data, password: String) throws -> Data {
        // Derive a key from the password
        let salt = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        let key = try deriveKey(from: password, salt: salt)

        // Generate a random nonce
        let nonce = AES.GCM.Nonce()

        // Encrypt the data
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)

        // Combine salt + nonce + ciphertext + tag
        var result = Data()
        result.append(salt)
        result.append(nonce.withUnsafeBytes { Data($0) })
        result.append(sealedBox.ciphertext)
        result.append(sealedBox.tag)

        return result
    }

    private func decryptData(_ data: Data, password: String) throws -> Data {
        guard data.count > 16 + 12 + 16 else {
            throw EncryptionError.invalidData
        }

        // Extract components
        let salt = data.prefix(16)
        let nonceData = data.dropFirst(16).prefix(12)
        let ciphertext = data.dropFirst(16 + 12).dropLast(16)
        let tag = data.suffix(16)

        // Derive the key
        let key = try deriveKey(from: password, salt: salt)

        // Create nonce
        let nonce = try AES.GCM.Nonce(data: nonceData)

        // Create sealed box
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)

        // Decrypt
        return try AES.GCM.open(sealedBox, using: key)
    }

    private func deriveKey(from password: String, salt: Data) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw EncryptionError.invalidPassword
        }

        // Use PBKDF2 to derive a key
        let rounds = 100_000
        let keyData = try pbkdf2(password: passwordData, salt: salt, rounds: rounds, keyByteCount: 32)
        return SymmetricKey(data: keyData)
    }

    private func pbkdf2(password: Data, salt: Data, rounds: Int, keyByteCount: Int) throws -> Data {
        var derivedKeyData = Data(repeating: 0, count: keyByteCount)
        let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                password.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(rounds),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyByteCount
                    )
                }
            }
        }

        guard derivationStatus == kCCSuccess else {
            throw EncryptionError.keyDerivationFailed
        }

        return derivedKeyData
    }
}

// MARK: - Encryption Errors

enum EncryptionError: Error, LocalizedError {
    case invalidData
    case invalidPassword
    case keyDerivationFailed
    case encryptionFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "The encrypted data is invalid or corrupted"
        case .invalidPassword:
            return "The password is invalid"
        case .keyDerivationFailed:
            return "Failed to derive encryption key"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data - incorrect password or corrupted data"
        }
    }
}

// Import CommonCrypto for PBKDF2
import CommonCrypto
