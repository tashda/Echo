import Foundation
import Observation
import SQLServerKit
import Logging

@Observable @MainActor
final class ProfilerViewModel {
    var isRunning = false
    var events: [SQLServerProfilerEvent] = []
    var selectedEventID: UUID?
    var targetDatabase: String?
    var selectedTraceEvents: Set<SQLTraceEvent> = [.sqlBatchCompleted, .rpcCompleted]
    
    private let profilerClient: SQLServerProfilerClient?
    private let connectionSessionID: UUID
    private var timer: Timer?
    private let logger = Logger(label: "ProfilerViewModel")
    private let sessionName: String

    init(profilerClient: SQLServerProfilerClient?, connectionSessionID: UUID) {
        self.profilerClient = profilerClient
        self.connectionSessionID = connectionSessionID
        self.sessionName = "Echo_Profiler_\(UUID().uuidString.prefix(8))"
    }

    func toggleTracing() {
        if isRunning {
            stopTracing()
        } else {
            startTracing()
        }
    }

    func startTracing() {
        guard let client = profilerClient else { return }
        
        Task {
            do {
                try await client.startLiveTrace(
                    name: sessionName,
                    events: Array(selectedTraceEvents),
                    targetDatabase: targetDatabase
                )
                isRunning = true
                startPolling()
            } catch {
                logger.error("Failed to start profiler: \(error)")
            }
        }
    }

    func stopTracing() {
        guard let client = profilerClient else { return }
        isRunning = false
        stopPolling()
        
        Task {
            do {
                try await client.stopLiveTrace(name: sessionName)
            } catch {
                logger.error("Failed to stop profiler: \(error)")
            }
        }
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollEvents()
            }
        }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func pollEvents() async {
        guard isRunning, let client = profilerClient else { return }
        do {
            let newEvents = try await client.readTraceEvents(sessionName: sessionName)
            if !newEvents.isEmpty {
                // Merge and deduplicate if necessary, or just append
                // XE ring buffer might return some overlapping events depending on timing
                events.append(contentsOf: newEvents)
                if events.count > 2000 {
                    events.removeFirst(events.count - 2000)
                }
            }
        } catch {
            logger.error("Profiler poll failed: \(error)")
        }
    }

    func clear() {
        events.removeAll()
        selectedEventID = nil
    }

    func refresh() {
        clear()
        // No-op for XE if already running, but we can restart polling
        if isRunning {
            stopPolling()
            startPolling()
        }
    }
    
    var selectedEvent: SQLServerProfilerEvent? {
        events.first { $0.id == selectedEventID }
    }
}
