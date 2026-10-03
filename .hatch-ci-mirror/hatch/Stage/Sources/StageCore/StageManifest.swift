import Foundation

/// What a Proposal hands in. The JSON is the same as `ProposalManifest` of the HatchAgent module (Stage cannot depend on
/// HatchAgent, so the model is redefined here). Every list may be missing; decoding stays forgiving and the quality gate in Hatch
/// says what is absent. A few optional keys are Stage-only (`mixSpecimen`, `plan`, `matchNote`); Hatch ignores them.
public struct StageManifest: Codable, Equatable {
    public var title: String
    public var revision: Int
    /// Spec IDs this Proposal changes, for example `TABS-2.4`.
    public var specs: [String]
    public var summary: String
    public var asked: String
    public var controls: [StageControl]
    public var specimens: [StageSpecimen]
    public var questions: [StageQuestion]
    public var exhibitTopic: StageTopic?
    public var presets: [StagePreset]
    public var scenarios: [StageScenario]
    public var conformance: StageConformance?
    /// The specimen a Mix column is drawn with. Defaults to the last proposal specimen.
    public var mixSpecimen: String?
    /// What Accept would change; shown in the Accept sheet.
    public var plan: StageAcceptPlan?

    public init(title: String = "", revision: Int = 1, specs: [String] = [], summary: String = "", asked: String = "",
                controls: [StageControl] = [], specimens: [StageSpecimen] = [], questions: [StageQuestion] = [],
                exhibitTopic: StageTopic? = nil, presets: [StagePreset] = [], scenarios: [StageScenario] = [],
                conformance: StageConformance? = nil, mixSpecimen: String? = nil, plan: StageAcceptPlan? = nil) {
        self.title = title; self.revision = revision; self.specs = specs; self.summary = summary; self.asked = asked
        self.controls = controls; self.specimens = specimens; self.questions = questions
        self.exhibitTopic = exhibitTopic; self.presets = presets; self.scenarios = scenarios
        self.conformance = conformance; self.mixSpecimen = mixSpecimen; self.plan = plan
    }

    private enum CodingKeys: String, CodingKey {
        case title, revision, specs, summary, asked, controls, specimens, exhibits, questions, exhibitTopic
        case presets, scenarios, conformance, mixSpecimen, plan
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        revision = try c.decodeIfPresent(Int.self, forKey: .revision) ?? 1
        specs = try c.decodeIfPresent([String].self, forKey: .specs) ?? []
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        asked = try c.decodeIfPresent(String.self, forKey: .asked) ?? ""
        controls = try c.decodeIfPresent([StageControl].self, forKey: .controls) ?? []
        if let list = try c.decodeIfPresent([StageSpecimen].self, forKey: .specimens) {
            specimens = list
        } else {
            // The Echo Labs word is "exhibits"; Hatch says "specimens". Both are accepted.
            specimens = try c.decodeIfPresent([StageSpecimen].self, forKey: .exhibits) ?? []
        }
        questions = try c.decodeIfPresent([StageQuestion].self, forKey: .questions) ?? []
        exhibitTopic = try c.decodeIfPresent(StageTopic.self, forKey: .exhibitTopic)
        presets = try c.decodeIfPresent([StagePreset].self, forKey: .presets) ?? []
        scenarios = try c.decodeIfPresent([StageScenario].self, forKey: .scenarios) ?? []
        conformance = try c.decodeIfPresent(StageConformance.self, forKey: .conformance)
        mixSpecimen = try c.decodeIfPresent(String.self, forKey: .mixSpecimen)
        plan = try c.decodeIfPresent(StageAcceptPlan.self, forKey: .plan)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(revision, forKey: .revision)
        try c.encode(specs, forKey: .specs)
        try c.encode(summary, forKey: .summary)
        try c.encode(asked, forKey: .asked)
        try c.encode(controls, forKey: .controls)
        try c.encode(specimens, forKey: .specimens)
        try c.encode(questions, forKey: .questions)
        try c.encodeIfPresent(exhibitTopic, forKey: .exhibitTopic)
        try c.encode(presets, forKey: .presets)
        try c.encode(scenarios, forKey: .scenarios)
        try c.encodeIfPresent(conformance, forKey: .conformance)
        try c.encodeIfPresent(mixSpecimen, forKey: .mixSpecimen)
        try c.encodeIfPresent(plan, forKey: .plan)
    }

    public static func parse(data: Data) throws -> StageManifest {
        do { return try JSONDecoder().decode(StageManifest.self, from: data) }
        catch { throw StageManifestError.invalid("\(error)") }
    }

    public static func parse(json: String) throws -> StageManifest {
        try parse(data: Data(json.utf8))
    }
}

public enum StageManifestError: Error, CustomStringConvertible, Equatable {
    case invalid(String)
    public var description: String {
        switch self { case .invalid(let m): return "The manifest is not valid JSON for a Proposal: \(m)" }
    }
}

public struct StageChoice: Codable, Equatable, Hashable {
    public var id: String
    public var name: String
    public var summary: String?
    public var addedIn: Int?
    public init(id: String, name: String, summary: String? = nil, addedIn: Int? = nil) {
        self.id = id; self.name = name; self.summary = summary; self.addedIn = addedIn
    }
}

/// A knob. With a `question` it is part of the decision and has `recommend` and `why`; without one it is a playground knob.
public struct StageControl: Codable, Equatable {
    public var id: String
    public var title: String
    public var choices: [StageChoice]
    public var defaultChoice: String
    public var question: String?
    public var recommend: String?
    public var why: String?
    public var addedIn: Int?

    public init(id: String, title: String, choices: [StageChoice], defaultChoice: String, question: String? = nil,
                recommend: String? = nil, why: String? = nil, addedIn: Int? = nil) {
        self.id = id; self.title = title; self.choices = choices; self.defaultChoice = defaultChoice
        self.question = question; self.recommend = recommend; self.why = why; self.addedIn = addedIn
    }

    private enum CodingKeys: String, CodingKey { case id, title, choices, defaultChoice = "default", question, recommend, why, addedIn }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? id
        choices = try c.decodeIfPresent([StageChoice].self, forKey: .choices) ?? []
        defaultChoice = try c.decodeIfPresent(String.self, forKey: .defaultChoice) ?? choices.first?.id ?? ""
        question = try c.decodeIfPresent(String.self, forKey: .question)
        recommend = try c.decodeIfPresent(String.self, forKey: .recommend)
        why = try c.decodeIfPresent(String.self, forKey: .why)
        addedIn = try c.decodeIfPresent(Int.self, forKey: .addedIn)
    }

    /// A control with a question is part of the decision; the others are the Playground.
    public var isDecision: Bool { question != nil }
}

/// One thing drawn on the stage. The first is Echo today (`isEchoToday`), then each proposal.
public struct StageSpecimen: Codable, Equatable {
    public var id: String
    public var title: String
    public var summary: String
    public var isEchoToday: Bool
    public var designWidth: Double?
    public var designHeight: Double?
    public var addedIn: Int?
    /// Echo today only: when it was last checked against the real Echo ("checked 2 days ago").
    public var matchNote: String?
    /// Echo today only: true when Echo changed after the specimen was written (the badge turns into a warning).
    public var matchStale: Bool

    public init(id: String, title: String, summary: String = "", isEchoToday: Bool = false, designWidth: Double? = nil,
                designHeight: Double? = nil, addedIn: Int? = nil, matchNote: String? = nil, matchStale: Bool = false) {
        self.id = id; self.title = title; self.summary = summary; self.isEchoToday = isEchoToday
        self.designWidth = designWidth; self.designHeight = designHeight; self.addedIn = addedIn
        self.matchNote = matchNote; self.matchStale = matchStale
    }

    private enum CodingKeys: String, CodingKey { case id, title, summary, isEchoToday, designWidth, designHeight, addedIn, matchNote, matchStale }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? id
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        isEchoToday = try c.decodeIfPresent(Bool.self, forKey: .isEchoToday) ?? false
        designWidth = try c.decodeIfPresent(Double.self, forKey: .designWidth)
        designHeight = try c.decodeIfPresent(Double.self, forKey: .designHeight)
        addedIn = try c.decodeIfPresent(Int.self, forKey: .addedIn)
        matchNote = try c.decodeIfPresent(String.self, forKey: .matchNote)
        matchStale = try c.decodeIfPresent(Bool.self, forKey: .matchStale) ?? false
    }
}

/// A decision with no control behind it.
public struct StageQuestion: Codable, Equatable {
    public var id: String
    public var title: String
    public var question: String
    public var choices: [StageChoice]
    public var recommended: String?
    public var why: String?
    public var addedIn: Int?

    public init(id: String, title: String, question: String, choices: [StageChoice], recommended: String? = nil, why: String? = nil, addedIn: Int? = nil) {
        self.id = id; self.title = title; self.question = question; self.choices = choices
        self.recommended = recommended; self.why = why; self.addedIn = addedIn
    }

    private enum CodingKeys: String, CodingKey { case id, title, question, choices, recommended, why, addedIn }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? id
        question = try c.decodeIfPresent(String.self, forKey: .question) ?? ""
        choices = try c.decodeIfPresent([StageChoice].self, forKey: .choices) ?? []
        recommended = try c.decodeIfPresent(String.self, forKey: .recommended)
        why = try c.decodeIfPresent(String.self, forKey: .why)
        addedIn = try c.decodeIfPresent(Int.self, forKey: .addedIn)
    }
}

/// The topic that picks between the specimens (each gets Pick / Maybe / No). `recommended` is a specimen id.
public struct StageTopic: Codable, Equatable {
    public var id: String
    public var title: String
    public var question: String
    public var recommended: String?
    public var why: String?

    public init(id: String = "exhibit", title: String = "Which one?", question: String, recommended: String? = nil, why: String? = nil) {
        self.id = id; self.title = title; self.question = question; self.recommended = recommended; self.why = why
    }

    private enum CodingKeys: String, CodingKey { case id, title, question, recommended, why }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? "exhibit"
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Which one?"
        question = try c.decodeIfPresent(String.self, forKey: .question) ?? ""
        recommended = try c.decodeIfPresent(String.self, forKey: .recommended)
        why = try c.decodeIfPresent(String.self, forKey: .why)
    }
}

public struct StagePreset: Codable, Equatable {
    public var id: String
    public var name: String
    /// Control id to choice id.
    public var values: [String: String]
    public var isRecommended: Bool
    public var addedIn: Int?

    public init(id: String, name: String, values: [String: String], isRecommended: Bool = false, addedIn: Int? = nil) {
        self.id = id; self.name = name; self.values = values; self.isRecommended = isRecommended; self.addedIn = addedIn
    }

    private enum CodingKeys: String, CodingKey { case id, name, values, isRecommended, addedIn }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? id
        values = try c.decodeIfPresent([String: String].self, forKey: .values) ?? [:]
        isRecommended = try c.decodeIfPresent(Bool.self, forKey: .isRecommended) ?? false
        addedIn = try c.decodeIfPresent(Int.self, forKey: .addedIn)
    }
}

/// A named state applied to all specimens. Either it is drawn (`applicable`) or it says why not (decision H6).
public struct StageScenario: Codable, Equatable, Hashable {
    public var id: String
    public var title: String
    public var applicable: Bool
    public var notApplicableReason: String?
    public var addedIn: Int?

    public init(id: String, title: String? = nil, applicable: Bool = true, notApplicableReason: String? = nil, addedIn: Int? = nil) {
        self.id = id; self.title = title ?? id; self.applicable = applicable
        self.notApplicableReason = notApplicableReason; self.addedIn = addedIn
    }

    private enum CodingKeys: String, CodingKey { case id, title, applicable, notApplicableReason, addedIn }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? id
        applicable = try c.decodeIfPresent(Bool.self, forKey: .applicable) ?? true
        notApplicableReason = try c.decodeIfPresent(String.self, forKey: .notApplicableReason)
        addedIn = try c.decodeIfPresent(Int.self, forKey: .addedIn)
    }
}

/// How the accepted result is later compared with the real app (see CONFORMANCE.md).
public struct StageConformance: Codable, Equatable {
    public struct State: Codable, Equatable {
        public var id: String
        public var title: String
        public var observe: Double?
        public init(id: String, title: String, observe: Double? = nil) { self.id = id; self.title = title; self.observe = observe }
    }
    public var states: [State]
    public var subject: String
    public var knownDifferences: [String: String]

    public init(states: [State] = [], subject: String = "", knownDifferences: [String: String] = [:]) {
        self.states = states; self.subject = subject; self.knownDifferences = knownDifferences
    }

    private enum CodingKeys: String, CodingKey { case states, subject, knownDifferences }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        states = try c.decodeIfPresent([State].self, forKey: .states) ?? []
        subject = try c.decodeIfPresent(String.self, forKey: .subject) ?? ""
        knownDifferences = try c.decodeIfPresent([String: String].self, forKey: .knownDifferences) ?? [:]
    }
}

/// What Accept would change, shown in the Accept sheet (decision H16).
public struct StageAcceptPlan: Codable, Equatable {
    public struct Repo: Codable, Equatable {
        public var name: String
        public var branch: String
        public init(name: String, branch: String) { self.name = name; self.branch = branch }
    }
    public var repos: [Repo]
    public var tests: [String]
    public var tokenEstimate: Int?

    public init(repos: [Repo] = [], tests: [String] = [], tokenEstimate: Int? = nil) {
        self.repos = repos; self.tests = tests; self.tokenEstimate = tokenEstimate
    }

    private enum CodingKeys: String, CodingKey { case repos, tests, tokenEstimate }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        repos = try c.decodeIfPresent([Repo].self, forKey: .repos) ?? []
        tests = try c.decodeIfPresent([String].self, forKey: .tests) ?? []
        tokenEstimate = try c.decodeIfPresent(Int.self, forKey: .tokenEstimate)
    }
}

/// The standard scenario set every Proposal covers or marks not applicable (decision H6).
public enum StandardScenarios {
    public static let all: [(id: String, title: String)] = [
        ("rest", "Rest"), ("hover", "Hover"), ("pressed", "Pressed"), ("focus", "Focus"), ("disabled", "Disabled"),
        ("empty", "Empty"), ("error", "Error"), ("long-text", "Long text"), ("many-items", "Many items"), ("loading", "Loading"),
    ]

    /// `Long text`, `long_text` and `long-text` are the same scenario.
    public static func normalize(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }
}

// MARK: - Derived views of the manifest

/// One decision card: a control with a question, a free question, or the specimen topic.
public struct StageDecision: Equatable, Identifiable {
    public enum Source: Equatable { case control, question, specimens }
    public var id: String
    public var title: String
    public var question: String
    public var choices: [StageChoice]
    public var recommended: String?
    public var why: String?
    public var source: Source
    public var addedIn: Int?
    public init(id: String, title: String, question: String, choices: [StageChoice], recommended: String?, why: String?, source: Source, addedIn: Int? = nil) {
        self.id = id; self.title = title; self.question = question; self.choices = choices
        self.recommended = recommended; self.why = why; self.source = source; self.addedIn = addedIn
    }

    public func choiceName(_ choiceID: String) -> String {
        choices.first(where: { $0.id == choiceID })?.name ?? choiceID
    }
}

extension StageManifest {
    public var echoToday: StageSpecimen? { specimens.first(where: { $0.isEchoToday }) }
    public var proposalSpecimens: [StageSpecimen] { specimens.filter { !$0.isEchoToday } }
    public var decisionControls: [StageControl] { controls.filter { $0.isDecision } }
    public var playgroundControls: [StageControl] { controls.filter { !$0.isDecision } }

    public func specimen(_ id: String) -> StageSpecimen? { specimens.first(where: { $0.id == id }) }
    public func control(_ id: String) -> StageControl? { controls.first(where: { $0.id == id }) }

    /// The specimen a Mix column is drawn with.
    public var mixSpecimenID: String? {
        if let m = mixSpecimen, specimen(m) != nil { return m }
        return proposalSpecimens.last?.id
    }

    /// A revision above 1 marks what was added since (NEW badges).
    public func isNew(addedIn: Int?) -> Bool {
        guard let a = addedIn else { return false }
        return revision > 1 && a >= revision
    }

    /// What was added in the current revision, for the "New since your last review" card.
    public var newItems: [String] {
        guard revision > 1 else { return [] }
        var out: [String] = []
        for c in controls {
            if isNew(addedIn: c.addedIn) { out.append("New control: \(c.title)") }
            for ch in c.choices where isNew(addedIn: ch.addedIn) { out.append("New choice in \(c.title): \(ch.name)") }
        }
        for q in questions {
            if isNew(addedIn: q.addedIn) { out.append("New question: \(q.title)") }
            for ch in q.choices where isNew(addedIn: ch.addedIn) { out.append("New choice in \(q.title): \(ch.name)") }
        }
        for s in specimens where isNew(addedIn: s.addedIn) { out.append("New option: \(s.title)") }
        for p in presets where isNew(addedIn: p.addedIn) { out.append("New preset: \(p.name)") }
        for sc in scenarios where isNew(addedIn: sc.addedIn) { out.append("New scenario: \(sc.title)") }
        return out
    }

    /// The Proposal as it was at revision `n` (decision H15: revision switcher). Old options are never removed, so an earlier
    /// revision is the current one without what was added later. `n` at or above the latest returns the manifest unchanged.
    public func atRevision(_ n: Int) -> StageManifest {
        guard n < revision else { return self }
        func kept(_ added: Int?) -> Bool { added.map { $0 <= n } ?? true }
        var m = self
        m.revision = max(n, 1)
        m.controls = controls.filter { kept($0.addedIn) }.map { c in
            var c = c
            c.choices = c.choices.filter { kept($0.addedIn) }
            if !c.choices.contains(where: { $0.id == c.defaultChoice }), let first = c.choices.first { c.defaultChoice = first.id }
            if let r = c.recommend, !c.choices.contains(where: { $0.id == r }) { c.recommend = nil }
            return c
        }
        m.questions = questions.filter { kept($0.addedIn) }.map { q in
            var q = q
            q.choices = q.choices.filter { kept($0.addedIn) }
            if let r = q.recommended, !q.choices.contains(where: { $0.id == r }) { q.recommended = nil }
            return q
        }
        m.specimens = specimens.filter { kept($0.addedIn) }
        m.presets = presets.filter { kept($0.addedIn) }
        m.scenarios = scenarios.filter { kept($0.addedIn) }
        if let t = exhibitTopic, let r = t.recommended, !m.specimens.contains(where: { $0.id == r }) {
            var t = t
            t.recommended = nil
            m.exhibitTopic = t
        }
        if let mix = mixSpecimen, !m.specimens.contains(where: { $0.id == mix }) { m.mixSpecimen = nil }
        return m
    }

    /// Everything added after revision `n`, up to the latest; the "compare revisions" list (decision H15).
    public func additions(after n: Int) -> [String] {
        func later(_ a: Int?) -> Bool { a.map { $0 > n } ?? false }
        var out: [String] = []
        for c in controls {
            if later(c.addedIn) { out.append("New control: \(c.title)") }
            for ch in c.choices where later(ch.addedIn) { out.append("New choice in \(c.title): \(ch.name)") }
        }
        for q in questions {
            if later(q.addedIn) { out.append("New question: \(q.title)") }
            for ch in q.choices where later(ch.addedIn) { out.append("New choice in \(q.title): \(ch.name)") }
        }
        for s in specimens where later(s.addedIn) { out.append("New option: \(s.title)") }
        for p in presets where later(p.addedIn) { out.append("New preset: \(p.name)") }
        for sc in scenarios where later(sc.addedIn) { out.append("New scenario: \(sc.title)") }
        return out
    }

    /// The scenarios the strip shows. A manifest without any gets a single Rest scenario.
    public var effectiveScenarios: [StageScenario] {
        scenarios.isEmpty ? [StageScenario(id: "rest", title: "Rest")] : scenarios
    }

    public var applicableScenarios: [StageScenario] { effectiveScenarios.filter { $0.applicable } }

    /// Every decision card in the order of the panel: controls with a question, free questions, then the specimen topic.
    public var decisions: [StageDecision] {
        var out: [StageDecision] = []
        for c in controls where c.question != nil {
            out.append(StageDecision(id: c.id, title: c.title, question: c.question ?? "", choices: c.choices,
                                     recommended: c.recommend, why: c.why, source: .control, addedIn: c.addedIn))
        }
        for q in questions {
            out.append(StageDecision(id: q.id, title: q.title, question: q.question, choices: q.choices,
                                     recommended: q.recommended, why: q.why, source: .question, addedIn: q.addedIn))
        }
        if let t = exhibitTopic {
            let choices = proposalSpecimens.map { StageChoice(id: $0.id, name: $0.title, summary: $0.summary.isEmpty ? nil : $0.summary, addedIn: $0.addedIn) }
            out.append(StageDecision(id: t.id, title: t.title, question: t.question, choices: choices,
                                     recommended: t.recommended, why: t.why, source: .specimens))
        }
        return out
    }

    public func decision(_ id: String) -> StageDecision? { decisions.first(where: { $0.id == id }) }

    /// The value of every control when nothing was touched.
    public var defaultControlValues: [String: String] {
        var out: [String: String] = [:]
        for c in controls { out[c.id] = c.defaultChoice }
        return out
    }

    /// The recommended preset's values, or the recommendations of the decision controls when no preset is marked.
    public var recommendedControlValues: [String: String] {
        if let p = presets.first(where: { $0.isRecommended }) {
            var v = defaultControlValues
            for (k, x) in p.values { v[k] = x }
            return v
        }
        var v = defaultControlValues
        for c in controls { if let r = c.recommend { v[c.id] = r } }
        return v
    }
}
