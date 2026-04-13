import CryptoKit
import Foundation
import Observation
import os.log
import Supabase

/// Orchestrates E2E credential sync enrollment, unlock, and recovery.
///
/// ## Lifecycle
/// 1. **Enrollment** — user sets master password, generates recovery key, wraps project keys.
/// 2. **Unlock** — on app launch or new device, user enters master password to unlock.
/// 3. **Recovery** — user enters 24-word mnemonic to recover master key.
///
/// ## Security Invariants
/// - Master Password is NEVER stored or transmitted.
/// - Master Key is derived locally and stored ONLY in local Keychain.
/// - Server only receives wrapped (encrypted) keys and salts.
@Observable @MainActor
final class E2EEnrollmentManager {
    private let crypto = E2ECryptoService()
    private let keyStore: E2EKeyStore
    private let logger = Logger(subsystem: "dev.echodb.echo", category: "e2e")

    /// Whether the current user has E2E enrolled on the server.
    private(set) var isEnrolled = false

    /// Whether the master key is available for this session.
    var isUnlocked: Bool { keyStore.isUnlocked }

    /// Error from the last operation.
    private(set) var error: E2EError?

    init(keyStore: E2EKeyStore) {
        self.keyStore = keyStore
    }

    // MARK: - Check Enrollment Status

    /// Check if the current user has E2E enrolled. Called after sign-in.
    func checkEnrollmentStatus() async {
        // Reset to false before checking — prevents stale state from previous user
        isEnrolled = false
        error = nil

        guard let client = SupabaseConfig.sharedClient else { return }
        do {
            let userID = try await client.auth.session.user.id
            struct ProfileRow: Decodable { let e2e_enrolled: Bool }
            let rows: [ProfileRow] = try await client.from("profiles")
                .select("e2e_enrolled")
                .eq("id", value: userID)
                .execute()
                .value
            isEnrolled = rows.first?.e2e_enrolled ?? false
        } catch {
            logger.error("Failed to check E2E enrollment: \(error.localizedDescription)")
            isEnrolled = false
        }
    }

    /// Try to auto-unlock using Master Key in Keychain (app relaunch).
    func tryAutoUnlock() async {
        guard isEnrolled else { return }
        if let masterKey = keyStore.loadMasterKey() {
            do {
                try await loadProjectKeys(masterKey: masterKey)
                logger.info("E2E auto-unlocked from Keychain")
            } catch {
                // Master key in Keychain is stale or corrupt — need manual unlock
                keyStore.clearMasterKey()
                logger.warning("E2E auto-unlock failed, need manual unlock")
            }
        }
    }

    // MARK: - Enrollment

    /// Enroll in E2E credential sync. Returns the 24-word recovery mnemonic.
    ///
    /// - Parameter password: The master password chosen by the user.
    /// - Returns: The 24-word recovery key that the user must save offline.
    func enroll(password: String) async throws -> [String] {
        guard let client = SupabaseConfig.sharedClient else {
            throw E2EError.enrollmentFailed("Supabase not configured")
        }

        error = nil

        await checkEnrollmentStatus()
        if isEnrolled {
            throw E2EError.enrollmentFailed("Credential sync is already set up for this account. Enter your existing master password to unlock it, or use recovery if you forgot it.")
        }

        // 1. Generate salts
        let masterSalt = crypto.generateSalt()
        let recoverySalt = crypto.generateSalt()

        // 2. Derive Master Key from password
        let masterKey = try crypto.deriveKey(password: password, salt: masterSalt)

        // 3. Generate recovery mnemonic
        let (words, recoveryEntropy) = BIP39Mnemonic.generate()

        // 4. Derive Recovery KEK from mnemonic entropy
        let recoveryKEK = try crypto.deriveKey(
            password: String(data: recoveryEntropy.base64EncodedData(), encoding: .utf8) ?? "",
            salt: recoverySalt
        )

        // 5. Wrap Master Key with Recovery KEK
        let wrappedMasterKey = try crypto.wrapKey(masterKey, with: recoveryKEK)

        // 6. Hash recovery key for server-side verification (cannot recover from hash)
        let recoveryHash = SHA256.hash(data: recoveryEntropy)
        let recoveryHashHex = recoveryHash.map { String(format: "%02x", $0) }.joined()

        // 7. Generate per-project keys and wrap with Master Key
        let projectStore = AppDirector.shared.projectStore
        let syncEnabledProjects = projectStore.projects.filter { $0.isSyncEnabled }

        struct WrappedProjectKey {
            let projectID: UUID
            let wrappedKey: Data
        }
        var wrappedProjectKeys: [WrappedProjectKey] = []

        for project in syncEnabledProjects {
            let projectKey = crypto.generateKey()
            let wrapped = try crypto.wrapKey(projectKey, with: masterKey)
            wrappedProjectKeys.append(WrappedProjectKey(projectID: project.id, wrappedKey: wrapped))
            keyStore.setProjectKey(projectKey, for: project.id)
        }

        // 8. Upload to server
        let userID = try await client.auth.session.user.id

        // Update profile
        struct ProfileEnrollmentRow: Encodable {
            let id: UUID
            let e2e_enrolled: Bool
            let e2e_salt: String        // base64
            let e2e_wrapped_master_key: String  // base64
            let e2e_recovery_key_hash: String
            let e2e_recovery_salt: String  // base64
        }
        try await client.from("profiles")
            .upsert(ProfileEnrollmentRow(
                id: userID,
                e2e_enrolled: true,
                e2e_salt: masterSalt.base64EncodedString(),
                e2e_wrapped_master_key: wrappedMasterKey.base64EncodedString(),
                e2e_recovery_key_hash: recoveryHashHex,
                e2e_recovery_salt: recoverySalt.base64EncodedString()
            ), onConflict: "id")
            .execute()

        // Upload wrapped project keys
        for wpk in wrappedProjectKeys {
            let serverProjectID = SyncClient()?.serverProjectID(localID: wpk.projectID, userID: userID)
                ?? wpk.projectID

            struct KeyRow: Encodable {
                let user_id: UUID
                let project_id: UUID
                let wrapped_key: String  // base64
                let nonce: String        // base64 (empty — nonce is embedded in the blob)
            }
            try await client.from("encrypted_project_keys")
                .upsert(KeyRow(
                    user_id: userID,
                    project_id: serverProjectID,
                    wrapped_key: wpk.wrappedKey.base64EncodedString(),
                    nonce: Data().base64EncodedString()
                ), onConflict: "user_id,project_id")
                .execute()
        }

        // 9. Store Master Key in local Keychain
        try keyStore.storeMasterKey(masterKey)
        isEnrolled = true

        logger.info("E2E enrollment complete for \(wrappedProjectKeys.count) projects")
        return words
    }

    // MARK: - Unlock

    /// Unlock with the master password. Derives the key and unwraps project keys.
    func unlock(password: String) async throws {
        guard let client = SupabaseConfig.sharedClient else {
            throw E2EError.notEnrolled
        }

        error = nil

        // 1. Fetch salt from server
        let userID = try await client.auth.session.user.id
        struct ProfileRow: Decodable {
            let e2e_salt: String?
        }
        let rows: [ProfileRow] = try await client.from("profiles")
            .select("e2e_salt")
            .eq("id", value: userID)
            .execute()
            .value

        guard let saltBase64 = rows.first?.e2e_salt, let salt = Data(base64Encoded: saltBase64) else {
            throw E2EError.notEnrolled
        }

        // 2. Derive Master Key
        let masterKey = try crypto.deriveKey(password: password, salt: salt)

        // 3. Verify by unwrapping project keys
        try await loadProjectKeys(masterKey: masterKey)

        // 4. Store in Keychain
        try keyStore.storeMasterKey(masterKey)
        logger.info("E2E unlocked successfully")
    }

    // MARK: - Recovery

    /// Recover using the 24-word mnemonic. Allows setting a new master password.
    func recover(mnemonic: [String], newPassword: String) async throws {
        guard let client = SupabaseConfig.sharedClient else {
            throw E2EError.notEnrolled
        }

        error = nil

        // 1. Validate mnemonic
        guard let entropy = BIP39Mnemonic.toEntropy(mnemonic) else {
            throw E2EError.invalidMnemonic
        }

        // 2. Fetch recovery salt and wrapped master key
        let userID = try await client.auth.session.user.id
        struct ProfileRow: Decodable {
            let e2e_recovery_salt: String?
            let e2e_wrapped_master_key: String?
        }
        let rows: [ProfileRow] = try await client.from("profiles")
            .select("e2e_recovery_salt, e2e_wrapped_master_key")
            .eq("id", value: userID)
            .execute()
            .value

        guard let recoverySaltB64 = rows.first?.e2e_recovery_salt,
              let recoverySalt = Data(base64Encoded: recoverySaltB64),
              let wrappedB64 = rows.first?.e2e_wrapped_master_key,
              let wrappedMasterKey = Data(base64Encoded: wrappedB64) else {
            throw E2EError.recoveryFailed("Missing recovery data on server")
        }

        // 3. Derive Recovery KEK
        let recoveryKEK = try crypto.deriveKey(
            password: String(data: entropy.base64EncodedData(), encoding: .utf8) ?? "",
            salt: recoverySalt
        )

        // 4. Unwrap Master Key
        let oldMasterKey: SymmetricKey
        do {
            oldMasterKey = try crypto.unwrapKey(wrappedMasterKey, with: recoveryKEK)
        } catch {
            throw E2EError.recoveryFailed("Invalid recovery key")
        }

        // 5. Load project keys with old master key
        try await loadProjectKeys(masterKey: oldMasterKey)

        // 6. Derive new Master Key from new password
        let newSalt = crypto.generateSalt()
        let newMasterKey = try crypto.deriveKey(password: newPassword, salt: newSalt)

        // 7. Re-wrap project keys with new Master Key
        let projectStore = AppDirector.shared.projectStore
        for project in projectStore.projects where project.isSyncEnabled {
            guard let projectKey = keyStore.projectKey(for: project.id) else { continue }
            let rewrapped = try crypto.wrapKey(projectKey, with: newMasterKey)
            let serverProjectID = SyncClient()?.serverProjectID(localID: project.id, userID: userID)
                ?? project.id

            struct KeyRow: Encodable {
                let user_id: UUID
                let project_id: UUID
                let wrapped_key: String
                let nonce: String
            }
            try await client.from("encrypted_project_keys")
                .upsert(KeyRow(
                    user_id: userID,
                    project_id: serverProjectID,
                    wrapped_key: rewrapped.base64EncodedString(),
                    nonce: Data().base64EncodedString()
                ), onConflict: "user_id,project_id")
                .execute()
        }

        // 8. Re-wrap new Master Key with Recovery KEK (recovery key stays the same)
        let newWrappedMasterKey = try crypto.wrapKey(newMasterKey, with: recoveryKEK)

        // 9. Update server
        struct ProfileRecoveryRow: Encodable {
            let id: UUID
            let e2e_salt: String
            let e2e_wrapped_master_key: String
        }
        try await client.from("profiles")
            .upsert(ProfileRecoveryRow(
                id: userID,
                e2e_salt: newSalt.base64EncodedString(),
                e2e_wrapped_master_key: newWrappedMasterKey.base64EncodedString()
            ), onConflict: "id")
            .execute()

        // 10. Store new Master Key locally
        try keyStore.storeMasterKey(newMasterKey)
        logger.info("E2E recovery complete, master password changed")
    }

    // MARK: - Sign Out

    func clearOnSignOut() {
        keyStore.clearAll()
        isEnrolled = false
        error = nil
    }

    // MARK: - Private

    /// Download and unwrap all project keys using the Master Key.
    /// Throws if the Master Key is wrong (GCM verification failure).
    private func loadProjectKeys(masterKey: SymmetricKey) async throws {
        guard let client = SupabaseConfig.sharedClient else { return }
        let userID = try await client.auth.session.user.id

        struct KeyRow: Decodable {
            let project_id: UUID
            let wrapped_key: String
        }

        let rows: [KeyRow] = try await client.from("encrypted_project_keys")
            .select("project_id, wrapped_key")
            .eq("user_id", value: userID)
            .execute()
            .value

        let syncClient = SyncClient()
        let projectStore = AppDirector.shared.projectStore

        for row in rows {
            guard let wrappedData = Data(base64Encoded: row.wrapped_key) else { continue }

            // Unwrap — if master key is wrong, this throws (GCM tag failure)
            let projectKey = try crypto.unwrapKey(wrappedData, with: masterKey)

            // Map server project ID back to local project ID
            let localProject = projectStore.projects.first { project in
                if let sc = syncClient {
                    return sc.serverProjectID(localID: project.id, userID: userID) == row.project_id
                }
                return project.id == row.project_id
            }

            if let localProject {
                keyStore.setProjectKey(projectKey, for: localProject.id)
            }
        }
    }
}
