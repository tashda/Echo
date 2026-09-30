import EchoSense
import Foundation
import Observation

/// Drives one EchoSense engine from the page's controls and recomputes on every change.
@Observable @MainActor
final class EchoSenseTestModel {
    var text = SampleSchema.defaultSQL { didSet { refresh() } }
    var caret = SampleSchema.defaultSQL.utf16.count { didSet { refresh() } }
    var databaseType: EchoSenseDatabaseType = .postgresql { didSet { refresh() } }
    var aggressiveness: SQLCompletionAggressiveness = .balanced { didSet { refresh() } }
    var includeSystemSchemas = false { didSet { refresh() } }
    var qualifyTables = false { didSet { refresh() } }
    var aliasShortcuts = false { didSet { refresh() } }
    var manualTrigger = false { didSet { refresh() } }
    /// A structure from a live connection; nil means the sample schema.
    var liveStructure: EchoSenseDatabaseStructure? { didSet { refresh() } }
    var liveSource: String?

    private(set) var response: SQLCompletionResponse?
    private(set) var elapsedMicroseconds = 0
    private let engine = SQLAutoCompletionEngine()

    init() { refresh() }

    var structure: EchoSenseDatabaseStructure { liveStructure ?? SampleSchema.structure(for: databaseType) }

    /// The text before and after the caret, for showing where completion happens.
    var caretContext: (before: String, after: String) {
        let ns = text as NSString
        let location = max(0, min(caret, ns.length))
        return (ns.substring(to: location), ns.substring(from: location))
    }

    func refresh() {
        let database = structure.databases.first
        engine.updateContext(SQLEditorCompletionContext(
            databaseType: databaseType,
            selectedDatabase: database?.name,
            defaultSchema: databaseType == .microsoftSQL ? "dbo" : (databaseType == .postgresql ? "public" : nil),
            structure: structure))
        engine.updatePreferences(SQLCompletionPreferences(
            includeHistory: false, includeSystemSchemas: includeSystemSchemas,
            qualifyTableInsertions: qualifyTables, autoJoinOnClause: true))
        engine.updateAggressiveness(aggressiveness)
        engine.updateAliasPreference(useTableAliases: aliasShortcuts)
        let start = ContinuousClock.now
        response = manualTrigger
            ? engine.manualCompletions(in: text, at: caret)
            : engine.completions(in: text, at: caret)
        let elapsed = ContinuousClock.now - start
        elapsedMicroseconds = Int(elapsed.components.attoseconds / 1_000_000_000_000) + Int(elapsed.components.seconds) * 1_000_000
    }

    func reset() {
        text = SampleSchema.defaultSQL
        caret = text.utf16.count
    }
}
