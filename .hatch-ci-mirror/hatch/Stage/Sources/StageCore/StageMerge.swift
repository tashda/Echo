import Foundation

/// What Hatch holds for a Proposal, in the Stage's own types. The adapter builds it from the local API's answer; Hatch is the
/// only writer (decision S3), so on a clean connection its copy wins over the file the Stage remembered.
public struct StageHatchSnapshot: Equatable {
    public struct Pick: Equatable {
        public var topic: String, choice: String, note: String?
        public init(topic: String, choice: String, note: String? = nil) { self.topic = topic; self.choice = choice; self.note = note }
    }
    public struct Verdict: Equatable {
        public var topic: String, option: String, verdict: String, note: String?
        public init(topic: String, option: String, verdict: String, note: String? = nil) {
            self.topic = topic; self.option = option; self.verdict = verdict; self.note = note
        }
    }
    public struct Pin: Equatable {
        public var id: Int
        public var text: String
        public var option: String?
        public var x: Double?, y: Double?
        public var scenario: String?
        public var appearance: String?
        public var corners: Int?
        public var zoom: Double?
        public init(id: Int, text: String, option: String? = nil, x: Double? = nil, y: Double? = nil, scenario: String? = nil,
                    appearance: String? = nil, corners: Int? = nil, zoom: Double? = nil) {
            self.id = id; self.text = text; self.option = option; self.x = x; self.y = y
            self.scenario = scenario; self.appearance = appearance; self.corners = corners; self.zoom = zoom
        }
    }
    public var picks: [Pick]
    public var verdicts: [Verdict]
    public var pins: [Pin]
    /// Revision number to its one-line summary, for the revision switcher.
    public var revisionSummaries: [Int: String]
    public init(picks: [Pick] = [], verdicts: [Verdict] = [], pins: [Pin] = [], revisionSummaries: [Int: String] = [:]) {
        self.picks = picks; self.verdicts = verdicts; self.pins = pins; self.revisionSummaries = revisionSummaries
    }
}

/// Lays Hatch's copy of the owner's answers over the state remembered on this Mac.
public enum StageMerge {
    /// Two pins are the same note when option and text match; the position can differ by rounding.
    public static func pinKey(text: String, option: String?) -> String {
        "\(option ?? "")|\(text.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    /// - Parameter hasPendingWrites: true when the Stage still holds writes Hatch has not received. Then the local answers are
    ///   newer than Hatch's, so only what is missing locally is added; nothing is replaced.
    public static func apply(_ snapshot: StageHatchSnapshot, to state: inout StageState, manifest m: StageManifest, hasPendingWrites: Bool) {
        let exhibitTopic = m.exhibitTopic?.id ?? "exhibit"
        var answers: [String: String] = [:]
        var verdicts: [String: StageVerdict] = [:]
        var topicNotes: [String: String] = [:]
        var optionNotes: [String: String] = [:]
        for pick in snapshot.picks {
            answers[pick.topic] = pick.choice
            if pick.topic == exhibitTopic {
                verdicts[pick.choice] = .pick
                if let n = pick.note, !n.isEmpty { optionNotes[pick.choice] = n }
            } else if let n = pick.note, !n.isEmpty {
                topicNotes[pick.topic] = n
            }
        }
        for v in snapshot.verdicts {
            guard let word = StageVerdict(rawValue: v.verdict) else { continue }
            verdicts[v.option] = word
            if let n = v.note, !n.isEmpty { optionNotes[v.option] = n }
        }

        if hasPendingWrites {
            for (k, v) in answers where state.answers[k] == nil { state.answers[k] = v }
            for (k, v) in verdicts where state.verdicts[k] == nil { state.verdicts[k] = v }
        } else {
            state.answers = answers
            state.verdicts = verdicts
            // An answer given means the topic is no longer "needs more options".
            for k in answers.keys { state.needsMore.remove(k) }
        }
        for (k, v) in topicNotes where (state.topicNotes[k] ?? "").isEmpty { state.topicNotes[k] = v }
        for (k, v) in optionNotes where (state.optionNotes[k] ?? "").isEmpty { state.optionNotes[k] = v }

        mergePins(snapshot.pins, into: &state)
    }

    /// Adds the pins Hatch has that the Stage does not, unless the owner removed them here.
    static func mergePins(_ pins: [StageHatchSnapshot.Pin], into state: inout StageState) {
        let hidden = Set(state.hiddenPinKeys ?? [])
        var known = Set(state.pins.map { pinKey(text: $0.text, option: $0.option) })
        var number = (state.pins.map { $0.number }.max() ?? 0)
        for p in pins {
            let key = pinKey(text: p.text, option: p.option)
            if known.contains(key) || hidden.contains(key) { continue }
            known.insert(key)
            number += 1
            state.pins.append(StagePin(
                id: "hatch.\(p.id)", number: number, text: p.text, option: p.option, x: p.x, y: p.y,
                scenario: p.scenario ?? state.scenario, appearance: p.appearance.flatMap { StageAppearance(rawValue: $0) } ?? .light,
                corners: p.corners ?? 10, zoom: p.zoom ?? 1.0))
        }
    }
}
