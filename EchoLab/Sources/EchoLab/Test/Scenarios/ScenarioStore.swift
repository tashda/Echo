import EchoSense
import EchoSenseScenarios
import Foundation
import Observation

/// The scenarios Echo Labs shows: read from, and written back to, the EchoSense checkout's
/// `Sources/EchoSenseScenarios/Scenarios`, so every edit is a git change in that repository and the
/// package's own tests run exactly what you see here.
@Observable @MainActor
final class ScenarioStore {
    static let shared = ScenarioStore()

    private(set) var library = ScenarioLibrary(scenarios: [])
    /// The shared rules (`Rules/rules.json` next to the scenarios).
    var ruleLibrary = ScenarioRuleLibrary()
    private(set) var results: [String: ScenarioResult] = [:]
    var loadError: String?
    private(set) var directory: URL

    init() {
        if let path = ProcessInfo.processInfo.environment["ECHOSENSE_SCENARIOS"] {
            directory = URL(fileURLWithPath: path)
        } else {
            // <repo>/EchoLab/Sources/EchoLab/Test/Scenarios/ScenarioStore.swift → the EchoSense checkout next to the repo.
            var url = URL(fileURLWithPath: #filePath)
            for _ in 0..<6 { url.deleteLastPathComponent() }
            directory = url.deletingLastPathComponent().appending(path: "echo-sense/Sources/EchoSenseScenarios/Scenarios")
        }
        reload()
    }

    var scenarios: [CompletionScenario] { library.scenarios }
    var rulesDirectory: URL { directory.deletingLastPathComponent().appending(path: "Rules") }
    /// Runs scenarios with the rules as they are on disk now, not as the package was built.
    var runner: CompletionScenarioRunner { CompletionScenarioRunner(rules: ruleLibrary.rules) }
    var groups: [String] { library.groups }

    func reload() {
        do {
            library = try ScenarioLibrary.load(directory: directory)
            ruleLibrary = try ScenarioRuleLibrary.load(directory: rulesDirectory)
            loadError = nil
            runAll()
        } catch {
            loadError = "\(error)"
            library = ScenarioLibrary(scenarios: [])
        }
    }

    func runAll() {
        results = Dictionary(uniqueKeysWithValues: runner.run(library.scenarios).map { ($0.id, $0) })
    }

    func result(for id: String) -> ScenarioResult? { results[id] }

    /// Replaces a scenario (or adds it), runs it and saves the files.
    func update(_ scenario: CompletionScenario) {
        if let index = library.scenarios.firstIndex(where: { $0.id == scenario.id }) {
            library.scenarios[index] = scenario
        } else {
            library.scenarios.append(scenario)
        }
        results[scenario.id] = runner.run(scenario)
        save()
    }

    func delete(id: String) {
        library.scenarios.removeAll { $0.id == id }
        results[id] = nil
        save()
    }

    func nextID(prefix: String) -> String { library.nextID(prefix: prefix) }

    @ObservationIgnored private var pendingSave: Task<Void, Never>?

    /// Saves shortly after the last edit, so typing doesn't rewrite the files on every key.
    private func save() {
        pendingSave?.cancel()
        pendingSave = Task(name: "scenario-save") { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, let self else { return }
            do { try self.library.write(to: self.directory) } catch { self.loadError = "Could not save: \(error)" }
        }
    }
}
