import Foundation
import os.log
import Supabase

/// Listens for realtime changes on the `sync_documents` table via Supabase WebSocket.
/// When another device pushes changes, this triggers an immediate pull on the local device.
@MainActor
final class SyncRealtimeListener {
    private let logger = Logger(subsystem: "dev.echodb.echo", category: "sync-realtime")
    private weak var syncEngine: SyncEngine?
    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?

    init(syncEngine: SyncEngine) {
        self.syncEngine = syncEngine
    }

    /// Start listening for remote changes. Call after sign-in.
    func start() async {
        guard let client = SupabaseConfig.sharedClient else {
            logger.warning("No Supabase client available for realtime")
            return
        }

        // Clean up any existing subscription
        await stop()

        let channel = client.realtimeV2.channel("sync-changes")

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "sync_documents"
        )

        self.channel = channel

        do {
            try await channel.subscribeWithError()
            logger.info("Realtime subscription active on sync_documents")
        } catch {
            logger.error("Realtime subscription failed: \(error.localizedDescription)")
            return
        }

        // Listen for changes in a background task
        listenTask = Task { [weak self] in
            for await _ in changes {
                guard let self, !Task.isCancelled else { break }
                self.logger.debug("Realtime change detected — triggering sync")
                await self.syncEngine?.syncNow()
            }
        }
    }

    /// Stop listening. Call on sign-out.
    func stop() async {
        listenTask?.cancel()
        listenTask = nil

        if let channel {
            await channel.unsubscribe()
            self.channel = nil
            logger.info("Realtime subscription stopped")
        }
    }
}
