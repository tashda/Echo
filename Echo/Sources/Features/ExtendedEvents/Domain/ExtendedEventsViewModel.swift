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

    enum SelectedSection: String, CaseIterable {
        case sessions = "Sessions"
        case liveData = "Live Data"
    }

    @ObservationIgnored private let xeClient: SQLServerExtendedEventsClient
    @ObservationIgnored let connectionSessionID: UUID

    var loadingState: LoadingState = .idle
    var sessions: [SQLServerXESession] = []
    var selectedSection: SelectedSection = .sessions
    var selectedSessionName: String?
    var sessionDetail: SQLServerXESessionDetail?
    var detailLoadingState: LoadingState = .idle
    var eventData: [SQLServerXEEventData] = []
    var eventDataLoadingState: LoadingState = .idle
    var togglingSessionName: String?

    // Create session state
    var showCreateSheet = false
    var createSessionName = ""
    var createEventName = "sqlserver.sql_statement_completed"
    var createPredicate = ""
    var createMaxMemoryKB = 4096
    var isCreating = false

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

    func createSession() async {
        guard !createSessionName.isEmpty else { return }
        isCreating = true
        do {
            var actions: [String] = [
                "sqlserver.sql_text",
                "sqlserver.database_name",
                "sqlserver.username"
            ]
            if createEventName.contains("sql_statement") {
                actions.append("sqlserver.client_hostname")
            }

            let eventSpec = SQLServerXESessionConfiguration.EventSpec(
                eventName: createEventName,
                actions: actions,
                predicate: createPredicate.isEmpty ? nil : createPredicate
            )
            let config = SQLServerXESessionConfiguration(
                name: createSessionName,
                events: [eventSpec],
                target: .ringBuffer(maxMemoryKB: createMaxMemoryKB)
            )
            try await xeClient.createSession(config)
            showCreateSheet = false
            resetCreateForm()
            await loadSessions()
        } catch {
            loadingState = .error(error.localizedDescription)
        }
        isCreating = false
    }

    private func resetCreateForm() {
        createSessionName = ""
        createEventName = "sqlserver.sql_statement_completed"
        createPredicate = ""
        createMaxMemoryKB = 4096
    }

    func estimatedMemoryUsageBytes() -> Int {
        let sessionsSize = sessions.count * 128
        let eventDataSize = eventData.count * 512
        return 1024 * 128 + sessionsSize + eventDataSize
    }
}
