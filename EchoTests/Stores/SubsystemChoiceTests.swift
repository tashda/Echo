import Testing
@testable import Echo
import SQLServerKit

@Suite("SubsystemChoice")
struct SubsystemChoiceTests {

    @Test("Has all 12 subsystem cases")
    func allCases() {
        #expect(SubsystemChoice.allCases.count == 12)
    }

    @Test("All cases have non-empty raw values")
    func rawValues() {
        for choice in SubsystemChoice.allCases {
            #expect(!choice.rawValue.isEmpty)
        }
    }

    @Test("All cases map to valid builder subsystems")
    func builderSubsystemMapping() {
        for choice in SubsystemChoice.allCases {
            let subsystem = choice.builderSubsystem
            #expect(!subsystem.rawValue.isEmpty)
        }
    }

    @Test("Core subsystems have expected builder values")
    func coreSubsystems() {
        #expect(SubsystemChoice.tsql.builderSubsystem == .tsql)
        #expect(SubsystemChoice.cmdExec.builderSubsystem == .cmdExec)
        #expect(SubsystemChoice.powershell.builderSubsystem == .powershell)
    }

    @Test("Replication subsystems have expected builder values")
    func replicationSubsystems() {
        #expect(SubsystemChoice.snapshot.builderSubsystem == .snapshot)
        #expect(SubsystemChoice.logReader.builderSubsystem == .logReader)
        #expect(SubsystemChoice.distribution.builderSubsystem == .distribution)
        #expect(SubsystemChoice.merge.builderSubsystem == .merge)
        #expect(SubsystemChoice.queueReader.builderSubsystem == .queueReader)
    }

    @Test("Analysis and SSIS subsystems have expected builder values")
    func analysisAndSSIS() {
        #expect(SubsystemChoice.ssis.builderSubsystem == .ssis)
        #expect(SubsystemChoice.analysisCommand.builderSubsystem == .analysisCommand)
        #expect(SubsystemChoice.analysisQuery.builderSubsystem == .analysisQuery)
        #expect(SubsystemChoice.activeScripting.builderSubsystem == .activeScripting)
    }
}
