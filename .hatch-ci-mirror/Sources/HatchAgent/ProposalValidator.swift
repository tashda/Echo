import Foundation

/// The quality gate for a Swift Proposal (decisions H19 and H6). It runs on `hatch offer`, while the agent can still fix
/// things, so the owner never sees a half-finished Proposal. Every rule is one small function in `rules`, with its own code.
public enum ProposalValidator {
    /// Everything a rule may look at.
    public struct Input {
        public var manifest: ProposalManifest
        /// The manifest of the revision the owner already saw. Needed to check the "keep old options" rule (H15).
        public var previous: ProposalManifest?
        /// What the owner has already answered: topic id to choice id.
        public var picks: [String: String]
    }

    public typealias Rule = (Input) -> [GateIssue]

    /// Smallest and largest design width the owner can judge comfortably, and the tallest design before it scrolls.
    public static let widthRange: ClosedRange<Double> = 340...700
    public static let maxHeight: Double = 620

    /// The gate. Add a rule here and write one test for its code.
    public static let rules: [Rule] = [
        echoTodayFirst, enoughProposals, specimenSizes, specimenSizeAdvice, duplicateIDs, controlQuestions, controlChoices,
        questionRules, exhibitTopicRules, standardScenarios, presetRules, revisionRules, specIDAdvice,
    ]

    public static func validate(_ manifest: ProposalManifest, previous: ProposalManifest? = nil, picks: [String: String] = [:]) -> [GateIssue] {
        let input = Input(manifest: manifest, previous: previous, picks: picks)
        return rules.flatMap { $0(input) }
    }

    // MARK: Specimens

    static func echoTodayFirst(_ i: Input) -> [GateIssue] {
        let s = i.manifest.specimens
        let today = s.filter(\.isEchoToday)
        if today.isEmpty {
            return [.error("echo-today.missing", "There is no Echo today specimen, so the owner has nothing to judge the options against.",
                           "Add a first specimen with isEchoToday true, drawn from what Echo really does (read the real view, not memory).")]
        }
        var out: [GateIssue] = []
        if s.first?.isEchoToday != true {
            out.append(.error("echo-today.first", "Echo today must be the first specimen, but '\(s.first?.id ?? "")' comes first.",
                              "Move the Echo today specimen to the top of the specimens list."))
        }
        if today.count > 1 {
            out.append(.error("echo-today.duplicate", "\(today.count) specimens are marked isEchoToday.", "Keep exactly one Echo today specimen."))
        }
        return out
    }

    static func enoughProposals(_ i: Input) -> [GateIssue] {
        let n = i.manifest.proposalSpecimens.count
        guard n < 2 else { return [] }
        return [.error("specimens.too-few", "There \(n == 1 ? "is 1 proposal" : "are \(n) proposals") besides Echo today; the owner needs at least 2 to choose between.",
                       "Offer at least 2 different proposals after Echo today (2 to 4 is the usual range).")]
    }

    static func specimenSizes(_ i: Input) -> [GateIssue] {
        i.manifest.specimens.compactMap { s in
            guard (s.designWidth ?? 0) > 0, (s.designHeight ?? 0) > 0 else {
                return .error("specimen.size-missing", "Specimen '\(s.id)' has no designWidth and designHeight.",
                              "Set both to the size Echo really draws it at; the Stage scales from them and 100% zoom depends on them.")
            }
            return nil
        }
    }

    static func specimenSizeAdvice(_ i: Input) -> [GateIssue] {
        i.manifest.specimens.compactMap { s in
            guard let w = s.designWidth, let h = s.designHeight, w > 0, h > 0 else { return nil }
            guard !widthRange.contains(w) || h > maxHeight else { return nil }
            return .warning("specimen.size-range", "Specimen '\(s.id)' is designed at \(Int(w)) x \(Int(h)); 340 to 700 wide and about 620 tall judges best.",
                            "Use a size in that range, or scroll inside the specimen. Ignore this if Echo really draws it that size.")
        }
    }

    // MARK: Ids

    static func duplicateIDs(_ i: Input) -> [GateIssue] {
        let m = i.manifest
        var out: [GateIssue] = []
        func check(_ kind: String, _ ids: [String]) {
            for id in Set(ids.filter { n in ids.filter { $0 == n }.count > 1 }).sorted() {
                out.append(.error("id.duplicate", "The \(kind) id '\(id)' is used more than once.", "Give every \(kind) its own id; picks and notes refer to these ids."))
            }
        }
        check("control", m.controls.map(\.id))
        check("specimen", m.specimens.map(\.id))
        check("question", m.questions.map(\.id))
        check("scenario", m.scenarios.map { StandardScenarios.normalize($0.id) })
        check("preset", m.presets.map(\.id))
        // A question may not reuse the id of a control with a question: both are topics the owner answers.
        check("topic", m.topicIDs)
        for c in m.controls { check("choice of control '\(c.id)'", c.choices.map(\.id)) }
        for q in m.questions { check("choice of question '\(q.id)'", q.choices.map(\.id)) }
        return out
    }

    // MARK: Controls and questions

    static func controlQuestions(_ i: Input) -> [GateIssue] {
        var out: [GateIssue] = []
        for c in i.manifest.controls where c.question != nil {
            out += recommendation(kind: "control", id: c.id, recommend: c.recommend, why: c.why, choices: c.choices.map(\.id), code: "control")
            if (c.question ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
                out.append(.error("control.question-empty", "Control '\(c.id)' has an empty question.", "Write what to look at, then what to decide."))
            }
        }
        return out
    }

    static func controlChoices(_ i: Input) -> [GateIssue] {
        var out: [GateIssue] = []
        for c in i.manifest.controls {
            if c.choices.isEmpty {
                out.append(.error("control.no-choices", "Control '\(c.id)' has no choices.", "Give it at least two choices."))
            } else if !c.choices.contains(where: { $0.id == c.defaultChoice }) {
                out.append(.error("control.default-unknown", "Control '\(c.id)' has default '\(c.defaultChoice)', which is not one of its choices.",
                                  "Set default to one of: \(c.choices.map(\.id).joined(separator: ", "))."))
            }
        }
        return out
    }

    static func questionRules(_ i: Input) -> [GateIssue] {
        var out: [GateIssue] = []
        for q in i.manifest.questions {
            out += recommendation(kind: "question", id: q.id, recommend: q.recommended, why: q.why, choices: q.choices.map(\.id), code: "question")
            if q.choices.count < 2 {
                out.append(.error("question.choices", "Question '\(q.id)' has \(q.choices.count) choice(s).", "A question needs at least two choices."))
            }
            if q.question.trimmingCharacters(in: .whitespaces).isEmpty {
                out.append(.error("question.text-empty", "Question '\(q.id)' has no question text.", "Write the question the owner answers."))
            }
        }
        return out
    }

    /// Shared by controls, questions: one recommendation that exists, with a reason (the owner's rule: every suggestion has both).
    private static func recommendation(kind: String, id: String, recommend: String?, why: String?, choices: [String], code: String) -> [GateIssue] {
        var out: [GateIssue] = []
        if (recommend ?? "").isEmpty {
            out.append(.error("\(code).recommend-missing", "The \(kind) '\(id)' has no recommendation.",
                              "Set the recommendation to the choice you would ship: one of \(choices.joined(separator: ", ")). Pick one, not a safe middle."))
        } else if !choices.contains(recommend!) {
            out.append(.error("\(code).recommend-unknown", "The \(kind) '\(id)' recommends '\(recommend!)', which is not one of its choices.",
                              "Recommend one of: \(choices.joined(separator: ", "))."))
        }
        if (why ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out.append(.error("\(code).why-missing", "The \(kind) '\(id)' has no reason for its recommendation.",
                              "Add 'why': the design reason in one or two sentences, saying what the other choices cost."))
        }
        return out
    }

    static func exhibitTopicRules(_ i: Input) -> [GateIssue] {
        guard let t = i.manifest.exhibitTopic else { return [] }
        var out: [GateIssue] = []
        let proposals = i.manifest.proposalSpecimens.map(\.id)
        if (t.recommended ?? "").isEmpty {
            out.append(.error("topic.recommend-missing", "The specimen topic '\(t.id)' has no recommendation.",
                              "Recommend one proposal: \(proposals.joined(separator: ", "))."))
        } else if !proposals.contains(t.recommended!) {
            out.append(.error("topic.recommend-not-proposal", "The specimen topic recommends '\(t.recommended!)', which is not one of the proposals.",
                              "Recommend one of the proposals (not Echo today): \(proposals.joined(separator: ", "))."))
        }
        if (t.why ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out.append(.error("topic.why-missing", "The specimen topic '\(t.id)' has no reason.", "Say why the recommended proposal beats Echo today and what it costs."))
        }
        return out
    }

    // MARK: Scenarios

    static func standardScenarios(_ i: Input) -> [GateIssue] {
        var out: [GateIssue] = []
        let byID = Dictionary(i.manifest.scenarios.map { (StandardScenarios.normalize($0.id), $0) }, uniquingKeysWith: { a, _ in a })
        for std in StandardScenarios.all {
            let found = byID[std.id] ?? i.manifest.scenarios.first { StandardScenarios.normalize($0.title) == std.id }
            guard let s = found else {
                out.append(.error("scenario.missing", "The standard scenario '\(std.title)' is neither drawn nor marked not applicable.",
                                  "Add a scenario with id '\(std.id)' and draw it, or set applicable false with a notApplicableReason."))
                continue
            }
            if !s.applicable && (s.notApplicableReason ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                out.append(.error("scenario.reason-missing", "The scenario '\(std.title)' is marked not applicable without a reason.",
                                  "Set notApplicableReason to a sentence saying why it cannot happen here."))
            }
        }
        return out
    }

    // MARK: Presets

    static func presetRules(_ i: Input) -> [GateIssue] {
        let m = i.manifest
        var out: [GateIssue] = []
        let recommended = m.presets.filter(\.isRecommended).count
        if recommended == 0 {
            out.append(.error("preset.recommended-missing", "No preset is marked isRecommended.", "Add a preset with your whole recommendation and mark it isRecommended true, so the owner can try it in one click."))
        } else if recommended > 1 {
            out.append(.error("preset.recommended-many", "\(recommended) presets are marked isRecommended.", "Keep exactly one recommended preset."))
        }
        for p in m.presets {
            for (control, choice) in p.values.sorted(by: { $0.key < $1.key }) {
                guard let c = m.controls.first(where: { $0.id == control }) else {
                    out.append(.error("preset.unknown-control", "Preset '\(p.id)' sets '\(control)', which is not a control.", "Use control ids from the controls list."))
                    continue
                }
                if !c.choices.contains(where: { $0.id == choice }) {
                    out.append(.error("preset.unknown-choice", "Preset '\(p.id)' sets '\(control)' to '\(choice)', which is not one of its choices.", "Use one of: \(c.choices.map(\.id).joined(separator: ", "))."))
                }
            }
        }
        return out
    }

    // MARK: Revisions (decision H15)

    static func revisionRules(_ i: Input) -> [GateIssue] {
        let m = i.manifest
        guard m.revision > 1 else { return [] }
        guard let old = i.previous else {
            return [.warning("revision.no-previous", "This is revision \(m.revision) but there is no earlier revision to compare with, so old options could not be checked.",
                             "Offer through `hatch offer` on the ticket so Hatch can compare with revision \(m.revision - 1).")]
        }
        var out: [GateIssue] = []
        if m.revision <= old.revision {
            out.append(.error("revision.number", "The manifest says revision \(m.revision) but revision \(old.revision) was already offered.", "Set revision to \(old.revision + 1)."))
        }
        // Old options stay, because the owner's earlier picks refer to them.
        func removed(_ kind: String, _ before: [String], _ after: [String]) {
            for id in before where !after.contains(id) {
                out.append(.error("revision.removed", "The \(kind) '\(id)' was in revision \(old.revision) and is gone.", "Put it back. Revisions keep old options and only add new ones."))
            }
        }
        removed("control", old.controls.map(\.id), m.controls.map(\.id))
        removed("specimen", old.specimens.map(\.id), m.specimens.map(\.id))
        removed("question", old.questions.map(\.id), m.questions.map(\.id))
        for oc in old.controls { if let nc = m.controls.first(where: { $0.id == oc.id }) { removed("choice of '\(oc.id)'", oc.choices.map(\.id), nc.choices.map(\.id)) } }
        for oq in old.questions { if let nq = m.questions.first(where: { $0.id == oq.id }) { removed("choice of '\(oq.id)'", oq.choices.map(\.id), nq.choices.map(\.id)) } }
        // Everything new says when it was added, so the owner gets NEW badges.
        func added(_ kind: String, _ items: [(id: String, addedIn: Int?)], _ before: [String]) {
            for item in items where !before.contains(item.id) && item.addedIn != m.revision {
                out.append(.error("revision.added-in", "The new \(kind) '\(item.id)' does not say addedIn \(m.revision).", "Set addedIn to \(m.revision) so the owner sees a NEW badge."))
            }
        }
        added("control", m.controls.map { ($0.id, $0.addedIn) }, old.controls.map(\.id))
        added("specimen", m.specimens.map { ($0.id, $0.addedIn) }, old.specimens.map(\.id))
        added("question", m.questions.map { ($0.id, $0.addedIn) }, old.questions.map(\.id))
        for c in m.controls {
            let before = old.controls.first { $0.id == c.id }?.choices.map(\.id) ?? []
            if old.controls.contains(where: { $0.id == c.id }) { added("choice of '\(c.id)'", c.choices.map { ($0.id, $0.addedIn) }, before) }
        }
        for q in m.questions {
            let before = old.questions.first { $0.id == q.id }?.choices.map(\.id) ?? []
            if old.questions.contains(where: { $0.id == q.id }) { added("choice of '\(q.id)'", q.choices.map { ($0.id, $0.addedIn) }, before) }
        }
        // Choice names of topics the owner already answered must not change: their saved pick refers to the choice.
        func renamed(_ topic: String, _ before: [ManifestChoice], _ after: [ManifestChoice]) {
            guard i.picks[topic] != nil else { return }
            for b in before { if let a = after.first(where: { $0.id == b.id }), a.name != b.name {
                out.append(.error("revision.renamed", "Choice '\(b.id)' of the answered topic '\(topic)' was renamed from '\(b.name)' to '\(a.name)'.",
                                  "Keep the name '\(b.name)'. The owner already answered this topic; add a new choice instead of renaming."))
            } }
        }
        for oc in old.controls where oc.question != nil { if let nc = m.controls.first(where: { $0.id == oc.id }) { renamed(oc.id, oc.choices, nc.choices) } }
        for oq in old.questions { if let nq = m.questions.first(where: { $0.id == oq.id }) { renamed(oq.id, oq.choices, nq.choices) } }
        if let t = old.exhibitTopic, i.picks[t.id] != nil {
            for os in old.specimens { if let ns = m.specimens.first(where: { $0.id == os.id }), ns.title != os.title {
                out.append(.error("revision.renamed", "Specimen '\(os.id)' was renamed from '\(os.title)' to '\(ns.title)' after the owner answered '\(t.id)'.", "Keep the name '\(os.title)'."))
            } }
        }
        return out
    }

    // MARK: Spec IDs

    static let specIDPattern = try! NSRegularExpression(pattern: "\\b[A-Z][A-Z0-9]*-[0-9]+(\\.[0-9]+)*\\b")

    static func specIDAdvice(_ i: Input) -> [GateIssue] {
        let s = i.manifest.summary
        let range = NSRange(s.startIndex..., in: s)
        if specIDPattern.firstMatch(in: s, range: range) == nil {
            return [.warning("summary.spec-id", "The summary names no Spec ID (for example TABS-2.4).",
                             "Look up the area in the Spec, and say in the summary which Spec IDs this changes.")]
        }
        return []
    }
}
