import Foundation
import os.log

/// Manages sync triggers: debounced data changes, idle timer, and manual sync.
///
/// The scheduler ensures the SyncEngine runs at appropriate times without
/// overwhelming the server. It debounces rapid local changes (5 seconds)
/// and runs a background timer for periodic sync (every 5 minutes).
@MainActor
final class SyncScheduler {

    // MARK: - Configuration

    private let changeDebounceInterval: TimeInterval = 5.0
    private let idleSyncInterval: TimeInterval = 300.0 // 5 minutes

    // MARK: - Dependencies

    private weak var syncEngine: SyncEngine?
    private let logger = Logger(subsystem: "dev.echodb.echo", category: "sync-scheduler")

    // MARK: - Internal State

    private var debounceTask: Task<Void, Never>?
    private var idleTimerTask: Task<Void, Never>?
    private var isRunning = false

    // MARK: - Init

    init(syncEngine: SyncEngine) {
        self.syncEngine = syncEngine
    }

    // MARK: - Lifecycle

    /// Start the scheduler. Called after sign-in.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        startIdleTimer()
        logger.info("Sync scheduler started")

        // Trigger an immediate sync on start
        triggerSync()
    }

    /// Stop the scheduler. Called on sign-out.
    func stop() {
        isRunning = false
        debounceTask?.cancel()
        debounceTask = nil
        idleTimerTask?.cancel()
        idleTimerTask = nil
        logger.info("Sync scheduler stopped")
    }

    // MARK: - Data Change Trigger

    /// Called when local data changes. Debounces rapid changes before triggering sync.
    func scheduleSync() {
        guard isRunning else { return }
        debounceTask?.cancel()
        let interval = changeDebounceInterval
        let engineRef = syncEngine
        debounceTask = Task.detached {
            do {
                try await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                await engineRef?.syncNow()
            } catch {
                // Task was cancelled — another change came in
            }
        }
    }

    /// Trigger sync immediately (user-initiated "Sync Now").
    func syncNow() {
        guard isRunning else { return }
        debounceTask?.cancel()
        triggerSync()
    }

    // MARK: - Private

    private func triggerSync() {
        let engineRef = syncEngine
        Task.detached {
            await engineRef?.syncNow()
        }
    }

    private func startIdleTimer() {
        idleTimerTask?.cancel()
        let interval = idleSyncInterval
        let engineRef = syncEngine
        idleTimerTask = Task.detached {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(interval))
                    guard !Task.isCancelled else { break }
                    await engineRef?.syncNow()
                } catch {
                    break
                }
            }
        }
    }
}
