import EchoSenseScenarios
import Foundation

/// Moving scenarios between areas, copying them, the shared rules, and the feedback threads.
/// Every change is written to the EchoSense checkout, like any other scenario edit.
extension ScenarioStore {
    // MARK: Areas

    /// Moves a scenario to another area (a new one if the name is new). An area left empty disappears.
    func move(_ id: String, toArea area: String) {
        let name = area.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, var scenario = library.scenario(id: id), scenario.group != name else { return }
        scenario.group = name
        update(scenario)
    }

    /// Copies a scenario, optionally into another area or dialect, and returns the copy's id. The copy
    /// keeps its checks and rules; its review and thread start fresh.
    @discardableResult
    func duplicate(_ id: String, toArea area: String? = nil, dialect: ScenarioDialect? = nil) -> String? {
        guard var copy = library.scenario(id: id) else { return nil }
        copy.id = nextID(prefix: "MINE")
        if let area { copy.group = area }
        if let dialect, dialect != copy.dialect {
            copy.dialect = dialect
            copy.title += " (\(dialect.title))"
        }
        copy.review = .imported
        copy.knownIssue = nil
        copy.comments = []
        copy.source = copy.source.map { "Copied from \(id), \($0)" } ?? "Copied from \(id)"
        update(copy)
        return copy.id
    }

    // MARK: Rules

    func rule(id: String) -> ScenarioRule? { ruleLibrary.rule(id: id) }

    func scenarios(following ruleID: String) -> [CompletionScenario] { scenarios.filter { $0.rules.contains(ruleID) } }

    /// Adds a rule and returns it; saved at once so scenarios can name it.
    func addRule(title: String, excludes: [String] = []) -> ScenarioRule {
        let rule = ScenarioRule(id: ruleLibrary.nextID(), title: title, excludes: excludes)
        ruleLibrary.rules.append(rule)
        saveRules()
        return rule
    }

    /// Replaces a rule and runs every scenario again, since any of them may follow it.
    func updateRule(_ rule: ScenarioRule) {
        guard let index = ruleLibrary.rules.firstIndex(where: { $0.id == rule.id }) else { return }
        ruleLibrary.rules[index] = rule
        saveRules()
        runAll()
    }

    /// Removes a rule and takes it off every scenario that followed it.
    func deleteRule(_ id: String) {
        for var scenario in scenarios(following: id) {
            scenario.rules.removeAll { $0 == id }
            update(scenario)
        }
        ruleLibrary.rules.removeAll { $0.id == id }
        saveRules()
        runAll()
    }

    func setFollows(_ ruleID: String, _ follows: Bool, scenario id: String) {
        guard var scenario = library.scenario(id: id), scenario.rules.contains(ruleID) != follows else { return }
        if follows { scenario.rules.append(ruleID) } else { scenario.rules.removeAll { $0 == ruleID } }
        update(scenario)
    }

    private func saveRules() {
        do { try ruleLibrary.write(to: rulesDirectory) } catch { loadError = "Could not save the rules: \(error)" }
    }

    // MARK: Feedback

    /// Adds the owner's message to a scenario's thread; an agent sees it through lab-inbox.py.
    func comment(_ text: String, about: String?, on id: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, var scenario = library.scenario(id: id) else { return }
        scenario.comments.append(ScenarioComment(author: .owner, text: text, about: about))
        update(scenario)
    }

    func deleteComment(_ commentID: String, on id: String) {
        guard var scenario = library.scenario(id: id) else { return }
        scenario.comments.removeAll { $0.id == commentID }
        update(scenario)
    }
}
