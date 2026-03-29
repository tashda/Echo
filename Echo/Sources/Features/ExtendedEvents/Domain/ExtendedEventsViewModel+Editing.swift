import Foundation
import SQLServerKit

// MARK: - Edit Session

extension ExtendedEventsViewModel {

    func prepareEditSession(_ sessionName: String) async {
        editingSessionName = sessionName
        editErrorMessage = nil
        isSavingEdits = false

        do {
            let detail = try await xeClient.sessionDetails(name: sessionName)
            let events = detail.events.map { event in
                EventEntry(eventName: "\(event.packageName).\(event.eventName)", actions: [], predicate: nil)
            }
            editEvents = events
            editOriginalEvents = events
            editTargets = detail.targets
            editOriginalTargets = detail.targets

            let sessions = try await xeClient.listSessions()
            editWasRunning = sessions.first(where: { $0.name == sessionName })?.isRunning ?? false
        } catch {
            editErrorMessage = error.localizedDescription
        }

        showEditSheet = true
    }

    func removeEditEvent(_ id: UUID) {
        editEvents.removeAll { $0.id == id }
    }

    func addEditEventEntry() {
        guard !newEventName.isEmpty else { return }
        let entry = EventEntry(
            eventName: newEventName,
            actions: Array(newEventActions).sorted(),
            predicate: newEventPredicate.isEmpty ? nil : newEventPredicate
        )
        editEvents.append(entry)
        newEventName = ""
        newEventPredicate = ""
        newEventActions = ["sqlserver.sql_text", "sqlserver.database_name", "sqlserver.username"]
    }

    /// Computes the diff between original and current edit events.
    func computeEditDiff() -> (eventsToAdd: [EventEntry], eventsToDrop: [String]) {
        Self.computeEventDiff(original: editOriginalEvents, current: editEvents)
    }

    /// Pure function for computing the event diff between two lists.
    /// Enables unit testing without requiring a live database client.
    static func computeEventDiff(
        original: [EventEntry],
        current: [EventEntry]
    ) -> (eventsToAdd: [EventEntry], eventsToDrop: [String]) {
        let originalNames = Set(original.map(\.eventName))
        let currentNames = Set(current.map(\.eventName))

        let toDrop = originalNames.subtracting(currentNames).sorted()
        let toAdd = current.filter { !originalNames.contains($0.eventName) }

        return (eventsToAdd: toAdd, eventsToDrop: toDrop)
    }

    func saveEditSession() async {
        guard let sessionName = editingSessionName else { return }
        isSavingEdits = true
        editErrorMessage = nil

        let diff = computeEditDiff()

        guard !diff.eventsToAdd.isEmpty || !diff.eventsToDrop.isEmpty else {
            showEditSheet = false
            isSavingEdits = false
            return
        }

        do {
            // Stop session if running
            if editWasRunning {
                try await xeClient.stopSession(name: sessionName)
            }

            // Drop removed events
            for eventName in diff.eventsToDrop {
                let parts = eventName.split(separator: ".", maxSplits: 1)
                let unqualified = parts.count > 1 ? String(parts[1]) : eventName
                try await xeClient.dropEvent(sessionName: sessionName, eventName: unqualified)
            }

            // Add new events
            for entry in diff.eventsToAdd {
                let parts = entry.eventName.split(separator: ".", maxSplits: 1)
                let unqualified = parts.count > 1 ? String(parts[1]) : entry.eventName
                try await xeClient.addEvent(
                    sessionName: sessionName,
                    eventName: unqualified,
                    predicate: entry.predicate
                )
            }

            // Restart session if it was running
            if editWasRunning {
                try await xeClient.startSession(name: sessionName)
            }

            showEditSheet = false
            resetEditForm()
            await loadSessions()
            await selectSession(sessionName)
        } catch {
            editErrorMessage = error.localizedDescription
            // Try to restart the session if we stopped it
            if editWasRunning {
                try? await xeClient.startSession(name: sessionName)
            }
        }
        isSavingEdits = false
    }

    func resetEditForm() {
        editingSessionName = nil
        editEvents = []
        editOriginalEvents = []
        editTargets = []
        editOriginalTargets = []
        editErrorMessage = nil
        editWasRunning = false
        newEventName = ""
        newEventPredicate = ""
        newEventActions = ["sqlserver.sql_text", "sqlserver.database_name", "sqlserver.username"]
    }
}
