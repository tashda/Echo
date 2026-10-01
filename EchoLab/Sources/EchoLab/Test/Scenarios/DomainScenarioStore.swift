import EchoSenseScenarios
import Foundation
import Observation

/// The domain scenarios (statements, GO batches, ...): read from and written back to the EchoSense
/// checkout's `Sources/EchoSenseScenarios/DomainScenarios`, like `ScenarioStore` does for completions.
@Observable @MainActor
final class DomainScenarioStore {
    static let shared = DomainScenarioStore()

    private(set) var library = DomainLibrary(scenarios: [])
    private(set) var results: [String: DomainResult] = [:]
    private(set) var loadError: String?
    let directory: URL

    init() {
        if let path = ProcessInfo.processInfo.environment["ECHOSENSE_DOMAIN_SCENARIOS"] {
            directory = URL(fileURLWithPath: path)
        } else {
            var url = URL(fileURLWithPath: #filePath)
            for _ in 0..<6 { url.deleteLastPathComponent() }
            directory = url.deletingLastPathComponent().appending(path: "EchoSense/Sources/EchoSenseScenarios/DomainScenarios")
        }
        reload()
    }

    func reload() {
        do {
            library = try DomainLibrary.load(directory: directory)
            loadError = nil
            runAll()
        } catch {
            loadError = "\(error)"
            library = DomainLibrary(scenarios: [])
        }
    }

    func runAll() {
        results = [:]
        for scenario in library.scenarios { run(scenario) }
    }

    private func run(_ scenario: DomainScenario) {
        guard let domain = ScenarioDomains.domain(id: scenario.domain) else { return }
        results[scenario.id] = domain.result(for: scenario)
    }

    func scenarios(in domain: String) -> [DomainScenario] { library.scenarios(in: domain) }
    func result(for id: String) -> DomainResult? { results[id] }
    func scenario(id: String) -> DomainScenario? { library.scenarios.first { $0.id == id } }

    func update(_ scenario: DomainScenario) {
        if let index = library.scenarios.firstIndex(where: { $0.id == scenario.id }) {
            library.scenarios[index] = scenario
        } else {
            library.scenarios.append(scenario)
        }
        run(scenario)
        save()
    }

    func delete(id: String) {
        library.scenarios.removeAll { $0.id == id }
        results[id] = nil
        save()
    }

    @ObservationIgnored private var pendingSave: Task<Void, Never>?

    private func save() {
        pendingSave?.cancel()
        pendingSave = Task(name: "domain-scenario-save") { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, let self else { return }
            do { try self.library.write(to: self.directory) } catch { self.loadError = "Could not save: \(error)" }
        }
    }

    struct Summary { var pass = 0, fail = 0, known = 0, unchecked = 0 }

    func summary(domain: String) -> Summary {
        var summary = Summary()
        for scenario in scenarios(in: domain) {
            switch results[scenario.id]?.verdict {
            case .pass: summary.pass += 1
            case .fail: summary.fail += 1
            case .knownIssue: summary.known += 1
            default: summary.unchecked += 1
            }
        }
        return summary
    }
}
