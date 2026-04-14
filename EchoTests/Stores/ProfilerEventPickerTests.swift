import Testing
@testable import Echo
import SQLServerKit

@Suite("Profiler Event Picker")
struct ProfilerEventPickerTests {

    @Test("SQLTraceEvent allCases is not empty")
    func traceEventCases() {
        #expect(!SQLTraceEvent.allCases.isEmpty)
        #expect(SQLTraceEvent.allCases.count >= 20)
    }

    @Test("Default selected events match Standard template")
    @MainActor
    func defaultSelectedEvents() {
        let vm = ProfilerViewModel(profilerClient: nil, session: nil, connectionSessionID: .init())
        #expect(vm.selectedTraceEvents.contains(.sqlBatchCompleted))
        #expect(vm.selectedTraceEvents.contains(.rpcCompleted))
        #expect(vm.selectedTraceEvents.count == 2)
    }

    @Test("Database list starts empty")
    @MainActor
    func databaseListEmpty() {
        let vm = ProfilerViewModel(profilerClient: nil, session: nil, connectionSessionID: .init())
        #expect(vm.databaseList.isEmpty)
        #expect(vm.targetDatabase == nil)
    }

    @Test("loadDatabases does nothing with nil session")
    @MainActor
    func loadDatabasesNilSession() async {
        let vm = ProfilerViewModel(profilerClient: nil, session: nil, connectionSessionID: .init())
        await vm.loadDatabases()
        #expect(vm.databaseList.isEmpty)
    }

    @Test("SQLTraceEvent xeEventName is non-empty for all cases")
    func xeEventNames() {
        for event in SQLTraceEvent.allCases {
            #expect(!event.xeEventName.isEmpty)
        }
    }

    @Test("Key trace events have expected XE names")
    func knownXeEventNames() {
        #expect(SQLTraceEvent.sqlBatchCompleted.xeEventName == "sql_batch_completed")
        #expect(SQLTraceEvent.rpcCompleted.xeEventName == "rpc_completed")
        #expect(SQLTraceEvent.deadlockGraph.xeEventName == "xml_deadlock_report")
        #expect(SQLTraceEvent.lockDeadlock.xeEventName == "lock_deadlock")
    }
}
