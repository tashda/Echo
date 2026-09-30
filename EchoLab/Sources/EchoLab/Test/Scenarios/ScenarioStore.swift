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
    private(set) var results: [String: ScenarioResult] = [:]
    private(set) var loadError: String?
    private(set) var directory: URL

    init() {
        if let path = ProcessInfo.processInfo.environment["ECHOSENSE_SCENARIOS"] {
            directory = URL(fileURLWithPath: path)
        } else {
            // <repo>/EchoLab/Sources/EchoLab/Test/Scenarios/ScenarioStore.swift → the EchoSense checkout next to the repo.
            var url = URL(fileURLWithPath: #filePath)
            for _ in 0..<6 { url.deleteLastPathComponent() }
            directory = url.deletingLastPathComponent().appending(path: "EchoSense/Sources/EchoSenseScenarios/Scenarios")
        }
        reload()
    }

    var scenarios: [CompletionScenario] { library.scenarios }
    var groups: [String] { library.groups }

    func reload() {
        do {
            library = try ScenarioLibrary.load(directory: directory)
            loadError = nil
            runAll()
        } catch {
            loadError = "\(error)"
            library = ScenarioLibrary(scenarios: [])
        }
    }

    func runAll() {
        results = Dictionary(uniqueKeysWithValues: CompletionScenarioRunner().run(library.scenarios).map { ($0.id, $0) })
    }

    func result(for id: String) -> ScenarioResult? { results[id] }

    /// Replaces a scenario (or adds it), runs it and saves the files.
    func update(_ scenario: CompletionScenario, runner: CompletionScenarioRunner = CompletionScenarioRunner()) {
        if let index = library.scenarios.firstIndex(where: { $0.id == scenario.id }) {
            library.scenarios[index] = scenario
        } else {
            library.scenarios.append(scenario)
        }
        results[scenario.id] = CompletionScenarioRunner().run(scenario)
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

    // MARK: Summary

    struct Summary { var pass = 0, fail = 0, known = 0, unchecked = 0, error = 0 }

    var summary: Summary {
        var summary = Summary()
        for scenario in library.scenarios {
            guard let result = results[scenario.id] else { continue }
            switch result.verdict {
            case .pass: summary.pass += 1
            case .unchecked: summary.unchecked += 1
            case .error: summary.error += 1
            case .fail: if scenario.knownIssue != nil { summary.known += 1 } else { summary.fail += 1 }
            }
        }
        return summary
    }
}
