import Observation
import SwiftUI

/// A round, as an agent writes it. This is the final format: describe the round in three lists
/// and the lab lays it out, wraps it to the window, remembers the owner's settings, and builds
/// the decision panel.
///
///     controls    the knobs the owner turns to try things (a header style, a speed…)
///     exhibits    live specimens, side by side (Echo today first, then each proposal)
///     questions   what to decide beyond the controls
///
/// See `EchoLab/HOW_TO_WRITE_A_ROUND.md` for the rules and a worked example.
@MainActor
struct RoundSpec {
    /// One knob. Its choices are also what the owner can pick in the decision panel, so a
    /// control that decides something needs a `question`.
    struct Control: Identifiable {
        let id: String
        let title: String
        /// What to look at and decide when turning this knob. Nil for playground-only knobs
        /// (speed, sample data) that are not part of the decision.
        var question: String?
        let choices: [RoundDecision.Choice]
        let defaultChoice: String
        /// What the agent recommends for this control, and why. Required when there is a `question`.
        var recommended: String?
        var why: String?
        /// The revision this control was added in (2 or more).
        var addedIn: Int?
    }

    /// One live specimen: a title, what makes it different, and the view.
    struct Exhibit: Identifiable {
        let id: String
        let title: String
        var summary = ""
        /// Marks the exhibit that shows what Echo does today.
        var isEchoToday = false
        /// A wide exhibit (a whole window) takes the full width of the canvas, on its own row.
        var isWide = false
        /// The revision this exhibit was added in (2 or more), so it is marked New until reviewed.
        var addedIn: Int?
        /// The size the specimen is designed at. It is scaled down if its card is narrower;
        /// keep it to about 340 to 700 wide so several fit side by side.
        let designWidth: CGFloat
        let designHeight: CGFloat
        let build: (RoundValues) -> AnyView

        init<V: View>(id: String, title: String, summary: String = "", isEchoToday: Bool = false, isWide: Bool = false,
                      addedIn: Int? = nil, designWidth: CGFloat, designHeight: CGFloat,
                      @ViewBuilder build: @escaping (RoundValues) -> V) {
            self.id = id
            self.title = title
            self.summary = summary
            self.isEchoToday = isEchoToday
            self.isWide = isWide
            self.addedIn = addedIn
            self.designWidth = designWidth
            self.designHeight = designHeight
            self.build = { AnyView(build($0)) }
        }
    }

    /// A decision that has no control: a question with choices.
    struct Question: Identifiable {
        let id: String
        let title: String
        let question: String
        let choices: [RoundDecision.Choice]
        /// The agent's recommendation (a choice id) and the reason. Both are required.
        let recommended: String
        let why: String
        /// The revision this question was added in (2 or more).
        var addedIn: Int?
    }

    /// A button that does something in the playground (post a notification, run the query).
    struct Action: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let perform: @MainActor (RoundValues) -> Void
    }

    var controls: [Control] = []
    /// Buttons shown with the controls.
    var actions: [Action] = []
    var exhibits: [Exhibit]
    var questions: [Question] = []
    /// When set, the decision has a topic that picks between the exhibits, and each exhibit
    /// card gets Pick, Maybe and No.
    var exhibitTopic: (title: String, question: String, recommended: String, why: String)?
    /// Named combinations of control settings; one click sets them all.
    var presets: [Preset] = []

    /// A named combination: control id to choice id. Controls it doesn't mention stay as they are.
    struct Preset: Identifiable {
        let id: String
        let name: String
        var summary: String?
        let values: [String: String]
        /// The preset that matches the agent's recommendation.
        var isRecommended = false
    }

    /// The decision panel: the exhibit topic, then every control that has a question (its
    /// current value is what "Use what's selected in the preview" picks), then the questions.
    func decision(values: RoundValues) -> RoundDecision {
        var topics: [RoundDecision.Topic] = []
        if let exhibitTopic {
            topics.append(.init(id: Self.exhibitTopicID, title: exhibitTopic.title, question: exhibitTopic.question,
                                choices: exhibits.map { .init(id: $0.id, name: $0.title, summary: nil, addedIn: $0.addedIn) },
                                recommended: exhibitTopic.recommended, why: exhibitTopic.why))
        }
        for control in controls {
            guard let question = control.question else { continue }
            assert(control.recommended != nil && control.why != nil,
                   "Control \(control.id) asks a question, so it needs a recommendation and a reason (see HOW_TO_WRITE_A_ROUND.md)")
            topics.append(.init(id: control.id, title: control.title, question: question, choices: control.choices,
                                recommended: control.recommended, why: control.why, addedIn: control.addedIn, preview: { values[control.id] }))
        }
        for question in questions {
            topics.append(.init(id: question.id, title: question.title, question: question.question, choices: question.choices,
                                recommended: question.recommended, why: question.why, addedIn: question.addedIn))
        }
        return RoundDecision(topics: topics)
    }

    static let exhibitTopicID = "exhibit"
}

/// The owner's current setting of every control on a round page, remembered between launches.
@Observable @MainActor
final class RoundValues {
    private let key: String
    private var values: [String: String]

    private static var cache: [String: RoundValues] = [:]

    /// One instance per round page, shared by the page and the decision panel.
    static func shared(pageID: String, controls: [RoundSpec.Control]) -> RoundValues {
        if let existing = cache[pageID] { return existing }
        let made = RoundValues(pageID: pageID, controls: controls)
        cache[pageID] = made
        return made
    }

    init(pageID: String, controls: [RoundSpec.Control]) {
        key = "roundValues." + pageID
        var initial = Dictionary(uniqueKeysWithValues: controls.map { ($0.id, $0.defaultChoice) })
        if let saved = LabPrefs.load(key, default: Optional<[String: String]>.none) {
            initial.merge(saved) { _, saved in saved }
        }
        values = initial
    }

    subscript(id: String) -> String {
        get { values[id] ?? "" }
        set { values[id] = newValue; LabPrefs.save(values, key: key) }
    }

    func apply(_ preset: RoundSpec.Preset) {
        for (key, value) in preset.values { values[key] = value }
        LabPrefs.save(values, key: key)
    }

    func matches(_ preset: RoundSpec.Preset) -> Bool {
        preset.values.allSatisfy { values[$0.key] == $0.value }
    }

    func reset(_ controls: [RoundSpec.Control]) {
        for control in controls { values[control.id] = control.defaultChoice }
        LabPrefs.save(values, key: key)
    }

    /// A binding to one control, for views that change it themselves.
    func binding(_ id: String) -> Binding<String> {
        Binding(get: { self[id] }, set: { self[id] = $0 })
    }
}

@MainActor
extension RoundSpec.Control {
    /// A control whose choices are the cases of an enum the exhibits already use.
    static func of<E: CaseIterable & RawRepresentable>(
        _ id: String, _ title: String, _ type: E.Type, default value: E, question: String? = nil,
        recommend: E? = nil, why: String? = nil, summary: ((E) -> String)? = nil,
        addedIn: Int? = nil, newChoices: (revision: Int, choices: [E])? = nil
    ) -> RoundSpec.Control where E.RawValue == String {
        RoundSpec.Control(id: id, title: title, question: question,
                          choices: RoundDecision.choices(type, summary: summary, added: newChoices), defaultChoice: value.rawValue,
                          recommended: recommend?.rawValue, why: why, addedIn: addedIn)
    }
}


extension LabPage {
    /// A round page written as a `RoundSpec`: the lab draws the info box, the controls and the
    /// exhibits, and puts the decision in the right-hand panel.
    @MainActor
    static func round(id: String, section: LabSection = .ongoing, group: String, title: String, symbol: String,
                      status: LabStatus, summary: String, spec: RoundSpec) -> LabPage {
        LabPage(id: id, section: section, group: group, title: title, symbol: symbol, status: status, summary: summary,
                ownsHeader: true,
                decision: { spec.decision(values: RoundValues.shared(pageID: id, controls: spec.controls)) }) {
            LabRoundPage(pageID: id, spec: spec)
        }
    }
}
