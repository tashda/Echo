import CryptoKit
import Foundation
import Supabase

/// HTTP client for the Supabase sync RPC endpoints.
///
/// Wraps the `SupabaseClient` to call `sync_pull` and `sync_push` Postgres
/// functions via PostgREST's RPC interface. The Supabase client handles
/// JWT injection and token refresh automatically.
nonisolated final class SyncClient: Sendable {
    private let client: SupabaseClient

    init?() {
        guard let client = SupabaseConfig.sharedClient else { return nil }
        self.client = client
    }

    // MARK: - Current User

    /// Returns the current authenticated user's ID.
    func currentUserID() async throws -> UUID {
        try await client.auth.session.user.id
    }

    // MARK: - Server Project ID

    /// Deterministic server-side project ID derived from local project ID + user ID.
    /// Each user gets their own namespace — no collisions between accounts.
    func serverProjectID(localID: UUID, userID: UUID) -> UUID {
        let input = "\(localID.uuidString):\(userID.uuidString)"
        let hash = SHA256.hash(data: Data(input.utf8))
        let bytes = Array(hash)
        // Build UUID from first 16 bytes of SHA-256, setting version 5 bits
        var uuid = [UInt8](bytes[0..<16])
        uuid[6] = (uuid[6] & 0x0F) | 0x50  // version 5
        uuid[8] = (uuid[8] & 0x3F) | 0x80  // variant 1
        return UUID(uuid: (uuid[0], uuid[1], uuid[2], uuid[3],
                           uuid[4], uuid[5], uuid[6], uuid[7],
                           uuid[8], uuid[9], uuid[10], uuid[11],
                           uuid[12], uuid[13], uuid[14], uuid[15]))
    }

    // MARK: - Pull

    /// Fetch documents changed since the given checkpoint for a project.
    func pull(checkpoint: UInt64, projectID: UUID) async throws -> SyncPullResponse {
        let params = SyncPullParams(
            p_checkpoint: Int64(checkpoint),
            p_project_id: projectID
        )

        let response: SyncPullResponse = try await client.rpc(
            "sync_pull",
            params: params
        ).execute().value

        return response
    }

    // MARK: - Push

    /// Push local changes to the server.
    func push(changes: [SyncDocument]) async throws -> SyncPushResponse {
        let params = SyncPushParams(p_changes: changes)

        let response: SyncPushResponse = try await client.rpc(
            "sync_push",
            params: params
        ).execute().value

        return response
    }

    // MARK: - Project Registration

    /// Ensure a project exists on the server for the current user.
    func upsertProject(serverID: UUID, userID: UUID, name: String, sortOrder: Int) async throws {
        struct ProjectRow: Encodable {
            let id: UUID
            let user_id: UUID
            let name: String
            let is_sync_enabled: Bool
            let sort_order: Int
        }

        try await client.from("projects")
            .upsert(ProjectRow(
                id: serverID,
                user_id: userID,
                name: name,
                is_sync_enabled: true,
                sort_order: sortOrder
            ))
            .execute()
    }
}

// MARK: - RPC Parameter Types

private struct SyncPullParams: Encodable, Sendable {
    let p_checkpoint: Int64
    let p_project_id: UUID
}

private struct SyncPushParams: Encodable, Sendable {
    let p_changes: [SyncDocument]
}
