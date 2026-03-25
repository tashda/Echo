import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("ExtendedEventsEditDiff")
struct ExtendedEventsEditDiffTests {

    private typealias EventEntry = ExtendedEventsViewModel.EventEntry

    // MARK: - No Changes

    @Test func noDiffWhenEventsUnchanged() {
        let events = [
            EventEntry(eventName: "sqlserver.sql_statement_completed", actions: [], predicate: nil),
            EventEntry(eventName: "sqlserver.rpc_completed", actions: [], predicate: nil)
        ]
        let diff = ExtendedEventsViewModel.computeEventDiff(original: events, current: events)
        #expect(diff.eventsToAdd.isEmpty)
        #expect(diff.eventsToDrop.isEmpty)
    }

    @Test func noDiffWhenBothEmpty() {
        let diff = ExtendedEventsViewModel.computeEventDiff(original: [], current: [])
        #expect(diff.eventsToAdd.isEmpty)
        #expect(diff.eventsToDrop.isEmpty)
    }

    // MARK: - Adding Events

    @Test func detectsAddedEvent() {
        let original = [
            EventEntry(eventName: "sqlserver.sql_statement_completed", actions: [], predicate: nil)
        ]
        let current = [
            EventEntry(eventName: "sqlserver.sql_statement_completed", actions: [], predicate: nil),
            EventEntry(eventName: "sqlserver.rpc_completed", actions: [], predicate: nil)
        ]
        let diff = ExtendedEventsViewModel.computeEventDiff(original: original, current: current)
        #expect(diff.eventsToAdd.count == 1)
        #expect(diff.eventsToAdd.first?.eventName == "sqlserver.rpc_completed")
        #expect(diff.eventsToDrop.isEmpty)
    }

    @Test func detectsMultipleAddedEvents() {
        let original: [EventEntry] = []
        let current = [
            EventEntry(eventName: "sqlserver.sql_statement_completed", actions: [], predicate: nil),
            EventEntry(eventName: "sqlserver.rpc_completed", actions: [], predicate: nil)
        ]
        let diff = ExtendedEventsViewModel.computeEventDiff(original: original, current: current)
        #expect(diff.eventsToAdd.count == 2)
        #expect(diff.eventsToDrop.isEmpty)
    }

    // MARK: - Dropping Events

    @Test func detectsDroppedEvent() {
        let original = [
            EventEntry(eventName: "sqlserver.sql_statement_completed", actions: [], predicate: nil),
            EventEntry(eventName: "sqlserver.rpc_completed", actions: [], predicate: nil)
        ]
        let current = [
            EventEntry(eventName: "sqlserver.sql_statement_completed", actions: [], predicate: nil)
        ]
        let diff = ExtendedEventsViewModel.computeEventDiff(original: original, current: current)
        #expect(diff.eventsToAdd.isEmpty)
        #expect(diff.eventsToDrop.count == 1)
        #expect(diff.eventsToDrop.first == "sqlserver.rpc_completed")
    }

    @Test func detectsAllEventsDropped() {
        let original = [
            EventEntry(eventName: "sqlserver.sql_statement_completed", actions: [], predicate: nil),
            EventEntry(eventName: "sqlserver.rpc_completed", actions: [], predicate: nil)
        ]
        let diff = ExtendedEventsViewModel.computeEventDiff(original: original, current: [])
        #expect(diff.eventsToAdd.isEmpty)
        #expect(diff.eventsToDrop.count == 2)
    }

    // MARK: - Mixed Add and Drop

    @Test func detectsSimultaneousAddAndDrop() {
        let original = [
            EventEntry(eventName: "sqlserver.sql_statement_completed", actions: [], predicate: nil),
            EventEntry(eventName: "sqlserver.rpc_completed", actions: [], predicate: nil)
        ]
        let current = [
            EventEntry(eventName: "sqlserver.sql_statement_completed", actions: [], predicate: nil),
            EventEntry(eventName: "sqlserver.error_reported", actions: [], predicate: nil)
        ]
        let diff = ExtendedEventsViewModel.computeEventDiff(original: original, current: current)
        #expect(diff.eventsToAdd.count == 1)
        #expect(diff.eventsToAdd.first?.eventName == "sqlserver.error_reported")
        #expect(diff.eventsToDrop.count == 1)
        #expect(diff.eventsToDrop.first == "sqlserver.rpc_completed")
    }

    @Test func completeReplacement() {
        let original = [
            EventEntry(eventName: "sqlserver.sql_statement_completed", actions: [], predicate: nil)
        ]
        let current = [
            EventEntry(eventName: "sqlserver.error_reported", actions: [], predicate: nil)
        ]
        let diff = ExtendedEventsViewModel.computeEventDiff(original: original, current: current)
        #expect(diff.eventsToAdd.count == 1)
        #expect(diff.eventsToAdd.first?.eventName == "sqlserver.error_reported")
        #expect(diff.eventsToDrop.count == 1)
        #expect(diff.eventsToDrop.first == "sqlserver.sql_statement_completed")
    }

    // MARK: - Drop Order

    @Test func droppedEventsAreSorted() {
        let original = [
            EventEntry(eventName: "sqlserver.rpc_completed", actions: [], predicate: nil),
            EventEntry(eventName: "sqlserver.error_reported", actions: [], predicate: nil),
            EventEntry(eventName: "sqlserver.sql_statement_completed", actions: [], predicate: nil)
        ]
        let diff = ExtendedEventsViewModel.computeEventDiff(original: original, current: [])
        #expect(diff.eventsToDrop == [
            "sqlserver.error_reported",
            "sqlserver.rpc_completed",
            "sqlserver.sql_statement_completed"
        ])
    }

    // MARK: - Predicate and Actions Preserved

    @Test func addedEventPreservesPredicateAndActions() {
        let original: [EventEntry] = []
        let current = [
            EventEntry(
                eventName: "sqlserver.sql_statement_completed",
                actions: ["sqlserver.sql_text", "sqlserver.database_name"],
                predicate: "duration > 1000000"
            )
        ]
        let diff = ExtendedEventsViewModel.computeEventDiff(original: original, current: current)
        #expect(diff.eventsToAdd.count == 1)
        let added = diff.eventsToAdd.first
        #expect(added?.actions == ["sqlserver.sql_text", "sqlserver.database_name"])
        #expect(added?.predicate == "duration > 1000000")
    }
}
