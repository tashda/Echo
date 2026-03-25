import Foundation
import SwiftUI
import SQLServerKit

/// View model for the Extended Events panel, managing session data and live event viewing.
@Observable
final class ExtendedEventsViewModel {
    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @ObservationIgnored let xeClient: SQLServerExtendedEventsClient
    @ObservationIgnored let connectionSessionID: UUID

    var loadingState: LoadingState = .idle
    var sessions: [SQLServerXESession] = []
    var selectedSessionName: String?
    var sessionDetail: SQLServerXESessionDetail?
    var detailLoadingState: LoadingState = .idle
    var eventData: [SQLServerXEEventData] = []
    var eventDataLoadingState: LoadingState = .idle
    var togglingSessionName: String?

    // Edit session state
    var showEditSheet = false
    var editingSessionName: String?
    var editEvents: [EventEntry] = []
    var editOriginalEvents: [EventEntry] = []
    var editTargets: [SQLServerXESessionTarget] = []
    var editOriginalTargets: [SQLServerXESessionTarget] = []
    var editTargetType: TargetChoice = .ringBuffer
    var editRingBufferKB = 4096
    var editEventFileName = ""
    var editEventFileMaxMB = 100
    var editErrorMessage: String?
    var isSavingEdits = false
    var editWasRunning = false

    // Create session state
    var showCreateSheet = false
    var isCreating = false
    var createSessionName = ""
    var createEvents: [EventEntry] = []
    var createTargetType: TargetChoice = .ringBuffer
    var createRingBufferKB = 4096
    var createEventFileName = ""
    var createEventFileMaxMB = 100
    var createMaxMemoryKB = 4096
    var createStartupState = false
    var createErrorMessage: String?

    // Available events catalog (loaded lazily)
    var availableEvents: [SQLServerXEEvent] = []
    var isLoadingAvailableEvents = false

    // Add-event form state
    var newEventName = ""
    var newEventPredicate = ""
    var newEventActions: Set<String> = ["sqlserver.sql_text", "sqlserver.database_name", "sqlserver.username"]

    struct EventEntry: Identifiable {
        let id = UUID()
        var eventName: String
        var actions: [String]
        var predicate: String?
    }

    enum TargetChoice: String, CaseIterable {
        case ringBuffer = "Ring Buffer"
        case eventFile = "Event File"
    }

    init(
        xeClient: SQLServerExtendedEventsClient,
        connectionSessionID: UUID
    ) {
        self.xeClient = xeClient
        self.connectionSessionID = connectionSessionID
    }

    func loadSessions() async {
        loadingState = .loading
        do {
            sessions = try await xeClient.listSessions()
            loadingState = .loaded
        } catch {
            loadingState = .error(error.localizedDescription)
        }
    }

    func toggleSession(_ session: SQLServerXESession) async {
        togglingSessionName = session.name
        do {
            if session.isRunning {
                try await xeClient.stopSession(name: session.name)
            } else {
                try await xeClient.startSession(name: session.name)
            }
            await loadSessions()
        } catch {
            loadingState = .error(error.localizedDescription)
        }
        togglingSessionName = nil
    }

    func selectSession(_ name: String) async {
        selectedSessionName = name
        detailLoadingState = .loading
        do {
            sessionDetail = try await xeClient.sessionDetails(name: name)
            detailLoadingState = .loaded
        } catch {
            detailLoadingState = .error(error.localizedDescription)
        }
    }

    func loadEventData() async {
        guard let name = selectedSessionName else { return }
        eventDataLoadingState = .loading
        do {
            let data = try await xeClient.readRingBufferData(sessionName: name, maxEvents: 200)
            eventData = data.sorted(by: { ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) })
            eventDataLoadingState = .loaded
        } catch {
            eventDataLoadingState = .error(error.localizedDescription)
        }
    }

    func dropSession(_ name: String) async {
        do {
            try await xeClient.dropSession(name: name)
            if selectedSessionName == name {
                selectedSessionName = nil
                sessionDetail = nil
                eventData = []
            }
            await loadSessions()
        } catch {
            loadingState = .error(error.localizedDescription)
        }
    }

    func loadAvailableEvents() async {
        guard availableEvents.isEmpty else { return }
        isLoadingAvailableEvents = true
        do {
            availableEvents = try await xeClient.listAvailableEvents()
        } catch {
            // Non-fatal — the picker will just show common events
        }
        isLoadingAvailableEvents = false
    }

    func addEventEntry() {
        guard !newEventName.isEmpty else { return }
        let entry = EventEntry(
            eventName: newEventName,
            actions: Array(newEventActions).sorted(),
            predicate: newEventPredicate.isEmpty ? nil : newEventPredicate
        )
        createEvents.append(entry)
        newEventName = ""
        newEventPredicate = ""
        newEventActions = ["sqlserver.sql_text", "sqlserver.database_name", "sqlserver.username"]
    }

    func removeEventEntry(_ id: UUID) {
        createEvents.removeAll { $0.id == id }
    }

    func createSession() async {
        guard !createSessionName.isEmpty, !createEvents.isEmpty else { return }
        isCreating = true
        createErrorMessage = nil
        do {
            let eventSpecs = createEvents.map { entry in
                SQLServerXESessionConfiguration.EventSpec(
                    eventName: entry.eventName,
                    actions: entry.actions,
                    predicate: entry.predicate
                )
            }
            let target: SQLServerXESessionConfiguration.TargetType = switch createTargetType {
            case .ringBuffer: .ringBuffer(maxMemoryKB: createRingBufferKB)
            case .eventFile: .eventFile(filename: createEventFileName, maxFileSizeMB: createEventFileMaxMB)
            }
            let config = SQLServerXESessionConfiguration(
                name: createSessionName,
                events: eventSpecs,
                target: target,
                maxMemoryKB: createMaxMemoryKB,
                startupState: createStartupState
            )
            try await xeClient.createSession(config)
            showCreateSheet = false
            resetCreateForm()
            await loadSessions()
        } catch {
            createErrorMessage = error.localizedDescription
        }
        isCreating = false
    }

    private func resetCreateForm() {
        createSessionName = ""
        createEvents = []
        createTargetType = .ringBuffer
        createRingBufferKB = 4096
        createEventFileName = ""
        createEventFileMaxMB = 100
        createMaxMemoryKB = 4096
        createStartupState = false
        createErrorMessage = nil
        newEventName = ""
        newEventPredicate = ""
        newEventActions = ["sqlserver.sql_text", "sqlserver.database_name", "sqlserver.username"]
    }

    func estimatedMemoryUsageBytes() -> Int {
        let sessionsSize = sessions.count * 128
        let eventDataSize = eventData.count * 512
        return 1024 * 128 + sessionsSize + eventDataSize
    }
}
