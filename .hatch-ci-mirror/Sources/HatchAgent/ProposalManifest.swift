import Foundation

/// What an agent hands in with `hatch offer` for a Swift Proposal. It mirrors the Echo Labs `RoundSpec`
/// (controls, exhibits, questions, topic, presets, conformance) so the Stage can draw it and the gate can check it.
/// Every list may be left out of the JSON; the quality gate says what is missing, so decoding stays forgiving.
public struct ProposalManifest: Codable, Equatable, Sendable {
    public var revision: Int
    /// Spec IDs this Proposal changes, for example `TABS-2.4`.
    public var specs: [String]
    public var summary: String
    /// What the owner asked, in one sentence.
    public var asked: String
    public var controls: [ManifestControl]
    public var specimens: [ManifestSpecimen]
    public var questions: [ManifestQuestion]
    public var exhibitTopic: ManifestTopic?
    public var presets: [ManifestPreset]
    public var scenarios: [ManifestScenario]
    public var conformance: ManifestConformance?

    public init(revision: Int = 1, specs: [String] = [], summary: String = "", asked: String = "",
                controls: [ManifestControl] = [], specimens: [ManifestSpecimen] = [], questions: [ManifestQuestion] = [],
                exhibitTopic: ManifestTopic? = nil, presets: [ManifestPreset] = [], scenarios: [ManifestScenario] = [],
                conformance: ManifestConformance? = nil) {
        self.revision = revision; self.specs = specs; self.summary = summary; self.asked = asked
        self.controls = controls; self.specimens = specimens; self.questions = questions
        self.exhibitTopic = exhibitTopic; self.presets = presets; self.scenarios = scenarios; self.conformance = conformance
    }

    private enum CodingKeys: String, CodingKey { case revision, specs, summary, asked, controls, specimens, exhibits, questions, exhibitTopic, presets, scenarios, conformance }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        revision = try c.decodeIfPresent(Int.self, forKey: .revision) ?? 1
        specs = try c.decodeIfPresent([String].self, forKey: .specs) ?? []
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        asked = try c.decodeIfPresent(String.self, forKey: .asked) ?? ""
        controls = try c.decodeIfPresent([ManifestControl].self, forKey: .controls) ?? []
        // The Echo Labs word is "exhibits"; Hatch says "specimens". Both are accepted.
        specimens = try c.decodeIfPresent([ManifestSpecimen].self, forKey: .specimens)
            ?? c.decodeIfPresent([ManifestSpecimen].self, forKey: .exhibits) ?? []
        questions = try c.decodeIfPresent([ManifestQuestion].self, forKey: .questions) ?? []
        exhibitTopic = try c.decodeIfPresent(ManifestTopic.self, forKey: .exhibitTopic)
        presets = try c.decodeIfPresent([ManifestPreset].self, forKey: .presets) ?? []
        scenarios = try c.decodeIfPresent([ManifestScenario].self, forKey: .scenarios) ?? []
        conformance = try c.decodeIfPresent(ManifestConformance.self, forKey: .conformance)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
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
    }

    /// Parses the JSON an agent hands in. Errors say where the JSON is wrong, in words an agent can act on.
    public static func parse(json: String) throws -> ProposalManifest {
        try parse(data: Data(json.utf8))
    }

    public static func parse(data: Data) throws -> ProposalManifest {
        do { return try JSONDecoder().decode(ProposalManifest.self, from: data) }
        catch { throw ManifestError.invalid(describe(error)) }
    }

    public func jsonString(pretty: Bool = true) throws -> String {
        let e = JSONEncoder()
        e.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return String(decoding: try e.encode(self), as: UTF8.self)
    }

    /// Ids of the topics the owner answers: every control with a question, every question, and the specimen topic.
    public var topicIDs: [String] {
        controls.filter { $0.question != nil }.map(\.id) + questions.map(\.id) + (exhibitTopic.map { [$0.id] } ?? [])
    }

    public var proposalSpecimens: [ManifestSpecimen] { specimens.filter { !$0.isEchoToday } }
}

public enum ManifestError: Error, CustomStringConvertible, Equatable {
    case invalid(String)
    public var description: String {
        switch self { case .invalid(let m): return "The manifest is not valid JSON for a Proposal: \(m)" }
    }
}

func describe(_ error: Error) -> String {
    func path(_ ctx: DecodingError.Context) -> String {
        let p = ctx.codingPath.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }.joined()
        return p.isEmpty ? "at the top level" : "at \(p.hasPrefix(".") ? String(p.dropFirst()) : p)"
    }
    guard let e = error as? DecodingError else { return "\(error)" }
    switch e {
    case .keyNotFound(let key, let ctx): return "missing \"\(key.stringValue)\" \(path(ctx))"
    case .typeMismatch(_, let ctx): return "wrong type \(path(ctx)): \(ctx.debugDescription)"
    case .valueNotFound(_, let ctx): return "missing value \(path(ctx))"
    case .dataCorrupted(let ctx): return "not valid JSON (\(ctx.debugDescription))"
    @unknown default: return "\(e)"
    }
}

public struct ManifestChoice: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var summary: String?
    public var addedIn: Int?
    public init(id: String, name: String, summary: String? = nil, addedIn: Int? = nil) {
        self.id = id; self.name = name; self.summary = summary; self.addedIn = addedIn
    }
}

/// A knob. With a `question` it is part of the decision and needs `recommend` and `why`; without one it is a playground knob.
public struct ManifestControl: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var choices: [ManifestChoice]
    public var defaultChoice: String
    public var question: String?
    public var recommend: String?
    public var why: String?
    public var addedIn: Int?
    public init(id: String, title: String, choices: [ManifestChoice], defaultChoice: String, question: String? = nil,
                recommend: String? = nil, why: String? = nil, addedIn: Int? = nil) {
        self.id = id; self.title = title; self.choices = choices; self.defaultChoice = defaultChoice
        self.question = question; self.recommend = recommend; self.why = why; self.addedIn = addedIn
    }
    private enum CodingKeys: String, CodingKey { case id, title, choices, defaultChoice = "default", question, recommend, why, addedIn }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? id
        choices = try c.decodeIfPresent([ManifestChoice].self, forKey: .choices) ?? []
        defaultChoice = try c.decodeIfPresent(String.self, forKey: .defaultChoice) ?? ""
        question = try c.decodeIfPresent(String.self, forKey: .question)
        recommend = try c.decodeIfPresent(String.self, forKey: .recommend)
        why = try c.decodeIfPresent(String.self, forKey: .why)
        addedIn = try c.decodeIfPresent(Int.self, forKey: .addedIn)
    }
}

/// One thing drawn on the stage. The first is Echo today (`isEchoToday`), then each proposal.
public struct ManifestSpecimen: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var summary: String
    public var isEchoToday: Bool
    public var designWidth: Double?
    public var designHeight: Double?
    public var addedIn: Int?
    public init(id: String, title: String, summary: String = "", isEchoToday: Bool = false, designWidth: Double? = nil,
                designHeight: Double? = nil, addedIn: Int? = nil) {
        self.id = id; self.title = title; self.summary = summary; self.isEchoToday = isEchoToday
        self.designWidth = designWidth; self.designHeight = designHeight; self.addedIn = addedIn
    }
    private enum CodingKeys: String, CodingKey { case id, title, summary, isEchoToday, designWidth, designHeight, addedIn }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? id
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        isEchoToday = try c.decodeIfPresent(Bool.self, forKey: .isEchoToday) ?? false
        designWidth = try c.decodeIfPresent(Double.self, forKey: .designWidth)
        designHeight = try c.decodeIfPresent(Double.self, forKey: .designHeight)
        addedIn = try c.decodeIfPresent(Int.self, forKey: .addedIn)
    }
}

/// A decision with no control behind it.
public struct ManifestQuestion: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var question: String
    public var choices: [ManifestChoice]
    public var recommended: String?
    public var why: String?
    public var addedIn: Int?
    public init(id: String, title: String, question: String, choices: [ManifestChoice], recommended: String? = nil, why: String? = nil, addedIn: Int? = nil) {
        self.id = id; self.title = title; self.question = question; self.choices = choices
        self.recommended = recommended; self.why = why; self.addedIn = addedIn
    }
    private enum CodingKeys: String, CodingKey { case id, title, question, choices, recommended, why, addedIn }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? id
        question = try c.decodeIfPresent(String.self, forKey: .question) ?? ""
        choices = try c.decodeIfPresent([ManifestChoice].self, forKey: .choices) ?? []
        recommended = try c.decodeIfPresent(String.self, forKey: .recommended)
        why = try c.decodeIfPresent(String.self, forKey: .why)
        addedIn = try c.decodeIfPresent(Int.self, forKey: .addedIn)
    }
}

/// The topic that picks between the specimens (each gets Pick / Maybe / No).
public struct ManifestTopic: Codable, Equatable, Sendable {
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

public struct ManifestPreset: Codable, Equatable, Sendable {
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

/// A named state applied to all specimens. Either it is drawn (`applicable`) or it says why not.
public struct ManifestScenario: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var applicable: Bool
    public var notApplicableReason: String?
    public var addedIn: Int?
    public init(id: String, title: String? = nil, applicable: Bool = true, notApplicableReason: String? = nil, addedIn: Int? = nil) {
        self.id = id; self.title = title ?? id; self.applicable = applicable; self.notApplicableReason = notApplicableReason; self.addedIn = addedIn
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
public struct ManifestConformance: Codable, Equatable, Sendable {
    public struct State: Codable, Equatable, Sendable {
        public var id: String
        public var title: String
        public var observe: Double?
        public init(id: String, title: String, observe: Double? = nil) { self.id = id; self.title = title; self.observe = observe }
    }
    public var states: [State]
    /// The `.conformanceTag` of the part everything is measured against.
    public var subject: String
    /// Part name (or `pixels:<part>`) to the reason it is expected to differ.
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

/// The standard scenario set every Proposal covers or marks not applicable (decision H6).
public enum StandardScenarios {
    public static let all: [(id: String, title: String)] = [
        ("rest", "Rest"), ("hover", "Hover"), ("pressed", "Pressed"), ("focus", "Focus"), ("disabled", "Disabled"),
        ("empty", "Empty"), ("error", "Error"), ("long-text", "Long text"), ("many-items", "Many items"), ("loading", "Loading"),
    ]

    /// `Long text`, `long_text` and `long-text` are the same scenario.
    public static func normalize(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "_", with: "-").replacingOccurrences(of: " ", with: "-")
    }
}

/// A sketch hands in 2 to 4 HTML variants instead (decision G).
public struct SketchManifest: Codable, Equatable, Sendable {
    public struct Variant: Codable, Equatable, Sendable {
        public var id: String
        public var title: String
        /// Path of the HTML file, relative to the folder the manifest sits in.
        public var html: String
        public var summary: String?
        public init(id: String, title: String, html: String, summary: String? = nil) {
            self.id = id; self.title = title; self.html = html; self.summary = summary
        }
    }
    public var summary: String
    public var variants: [Variant]
    public init(summary: String = "", variants: [Variant]) { self.summary = summary; self.variants = variants }

    private enum CodingKeys: String, CodingKey { case summary, variants }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        variants = try c.decodeIfPresent([Variant].self, forKey: .variants) ?? []
    }

    public static func parse(json: String) throws -> SketchManifest {
        do { return try JSONDecoder().decode(SketchManifest.self, from: Data(json.utf8)) }
        catch { throw ManifestError.invalid(describe(error)) }
    }

    /// 2 to 4 variants, each with a title, an id and an HTML file (which must exist when `baseDirectory` is given).
    public func validate(baseDirectory: URL? = nil) -> [GateIssue] {
        var out: [GateIssue] = []
        if variants.count < 2 || variants.count > 4 {
            out.append(.error("sketch.variant-count", "A Sketch needs 2 to 4 variants; this has \(variants.count).",
                              "Offer between 2 and 4 variants, each a different layout idea."))
        }
        var seen = Set<String>()
        for v in variants {
            if v.title.trimmingCharacters(in: .whitespaces).isEmpty {
                out.append(.error("sketch.title-missing", "Variant '\(v.id)' has no title.", "Give every variant a short title the owner can refer to, such as 'Header on top'."))
            }
            if !seen.insert(v.id).inserted {
                out.append(.error("sketch.id-duplicate", "Variant id '\(v.id)' is used twice.", "Give every variant its own id."))
            }
            if v.html.trimmingCharacters(in: .whitespaces).isEmpty {
                out.append(.error("sketch.html-missing", "Variant '\(v.id)' has no html path.", "Set html to the relative path of the variant's HTML file."))
            } else if v.html.hasPrefix("/") || v.html.contains("..") {
                out.append(.error("sketch.html-path", "Variant '\(v.id)' points outside the sketch folder (\(v.html)).", "Use a relative path inside the folder, such as a.html."))
            } else if let base = baseDirectory, !FileManager.default.fileExists(atPath: base.appendingPathComponent(v.html).path) {
                out.append(.error("sketch.html-not-found", "Variant '\(v.id)': the file \(v.html) does not exist.", "Write the HTML file next to the manifest before offering."))
            }
        }
        return out
    }
}
