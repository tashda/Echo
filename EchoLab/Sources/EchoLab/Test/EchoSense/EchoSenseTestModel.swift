import EchoSense
import Foundation
import Observation

/// Drives one EchoSense engine from the page's controls and recomputes on every change.
@Observable @MainActor
final class EchoSenseTestModel {
    private struct Saved: Codable {
        var text: String; var caret: Int; var dialect: EchoSenseDatabaseType; var aggressiveness: SQLCompletionAggressiveness
        var systemSchemas: Bool; var qualify: Bool; var alias: Bool; var manual: Bool
    }

    var text = SampleSchema.defaultSQL { didSet { changed() } }
    var caret = SampleSchema.defaultSQL.utf16.count { didSet { changed() } }
    var databaseType: EchoSenseDatabaseType = .postgresql { didSet { changed() } }
    var aggressiveness: SQLCompletionAggressiveness = .balanced { didSet { changed() } }
    var includeSystemSchemas = false { didSet { changed() } }
    var qualifyTables = false { didSet { changed() } }
    var aliasShortcuts = false { didSet { changed() } }
    var manualTrigger = false { didSet { changed() } }
    /// A structure from a live connection; nil means the sample schema.
    var liveStructure: EchoSenseDatabaseStructure? { didSet { refresh() } }
    var liveSource: String?

    /// Takes the schema (and dialect) loaded on the Connections page.
    func useLiveSchema() {
        guard let connection = LabLiveSession.shared.connection, let structure = connection.structure else { return }
        databaseType = connection.dialect
        liveStructure = structure
        liveSource = "Live: \(connection.profile.name)"
    }

    private(set) var response: SQLCompletionResponse?
    private(set) var elapsedMicroseconds = 0
    private let engine = SQLAutoCompletionEngine()

    init() {
        if let saved: Saved = LabPrefs.load("echosense", default: Optional<Saved>.none) {
            text = saved.text; caret = saved.caret; databaseType = saved.dialect; aggressiveness = saved.aggressiveness
            includeSystemSchemas = saved.systemSchemas; qualifyTables = saved.qualify; aliasShortcuts = saved.alias; manualTrigger = saved.manual
        }
        refresh()
    }

    /// Recomputes, and remembers what you typed and chose.
    private func changed() {
        LabPrefs.save(Saved(text: text, caret: caret, dialect: databaseType, aggressiveness: aggressiveness,
                            systemSchemas: includeSystemSchemas, qualify: qualifyTables, alias: aliasShortcuts, manual: manualTrigger), key: "echosense")
        refresh()
    }

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
