import Foundation
import CryptoKit

actor ProjectStore {
    private let fileURL: URL
    private let globalSettingsURL: URL

    init() {
        let fm = FileManager.default
        let appSupport = try! fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("Echo", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        fileURL = dir.appendingPathComponent("projects.json")
        globalSettingsURL = dir.appendingPathComponent("global_settings.json")
    }

    // MARK: - Projects

    func load() async throws -> [Project] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([Project].self, from: data)
    }

    func save(_ projects: [Project]) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(projects)
        try data.write(to: fileURL, options: [.atomic])
    }

    // MARK: - Global Settings

    func loadGlobalSettings() async throws -> GlobalSettings {
        let fm = FileManager.default
        guard fm.fileExists(atPath: globalSettingsURL.path) else {
            return await MainActor.run { GlobalSettings() }
        }
        let data = try Data(contentsOf: globalSettingsURL)
        return try await MainActor.run {
            try JSONDecoder().decode(GlobalSettings.self, from: data)
        }
    }

    func saveGlobalSettings(_ settings: GlobalSettings) async throws {
        let data = try await MainActor.run { () -> Data in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            return try encoder.encode(settings)
        }
        try data.write(to: globalSettingsURL, options: [.atomic])
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
            encoder.outputFormatting = [.prettyPrinted]
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
