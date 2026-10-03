import Foundation

/// A key on the stage (decision H20).
public enum StageKey: Equatable {
    case space, left, right
    case digit(Int)
    case character(Character)
    case commandReturn, commandShiftReturn
}

public enum StageAction: Equatable {
    // Looking
    case setMode(StageMode)
    case setAppearance(StageAppearance)
    case setIncreaseContrast(Bool)
    case setCorners(Int)
    case setTextSize(StageTextSize)
    case setReduceMotion(Bool)
    case setZoom(Double)
    case zoomStep(up: Bool)
    case toggleRedlines
    case setScenario(String)
    case nextScenario
    case selectOption(String)
    case stepOption(Int)
    case flip
    case setOverlayOpacity(Double)
    case setWipePosition(Double)
    case toggleShown(String)
    case showAllOptions
    case toggleFold(StagePanel)
    case autoFold(width: Double)
    case togglePinMode
    // Controls
    case setControl(id: String, value: String)
    case applyPreset(String)
    case applyRecommendedPreset
    case resetControls
    // Mix
    case toggleLiveMix
    case pinMix
    case removeMix(String)
    // Decision
    case answer(topic: String, choice: String)
    case useRecommendation(topic: String)
    case useAllRecommendations
    case usePreview(topic: String)
    case useAllPreview
    case setNeedsMore(topic: String, on: Bool)
    case setTopicNote(topic: String, text: String)
    case commitTopicNote(topic: String)
    case setVerdict(option: String, verdict: StageVerdict)
    case setOptionNote(option: String, text: String)
    case commitOptionNote(option: String)
    case setGeneralNote(String)
    case commitGeneralNote
    // Pins
    case addPin(text: String, option: String?, x: Double?, y: Double?)
    case openPin(String)
    case removePin(String)
    // Sheets
    case requestAccept
    case requestSendBack
    case requestAsk
    case toggleHelp
    case dismissSheet
    case setSendBackReason(StageSendBackReason)
    case setSendBackNote(String)
    case setAskDraft(String)
    case confirmAccept
    case confirmSendBack
    case sendAsk
    case dismissOutcome
    // Revisions (decision H15)
    case setViewRevision(Int?)
    case markRevisionSeen
    // Motion
    case togglePlay(duration: Double)
    case scrub(seconds: Double, duration: Double)
    case stepFrames(Int, duration: Double)
    case setSpeed(Double)
    case toggleLoop
    case tick(dt: Double, duration: Double)
    // Keyboard
    case key(StageKey)
}

/// What the reducer asks the outside world to do. The caller sends these to a `StageDataSource` (Hatch is the only writer).
public enum StageEffect: Equatable {
    case pick(topic: String, choice: String, note: String?)
    case verdict(topic: String, option: String, verdict: String, note: String?)
    case pin(StagePin)
    case note(kind: String, body: String)
    case accept(choices: [String: String])
    case sendBack(reason: String, note: String)
}

/// Pure functions for every user action. No SwiftUI, no I/O.
public enum StageReducer {

    // MARK: Entry point

    /// The manifest the owner is looking at: the latest, or an earlier revision picked in the revision switcher.
    public static func viewedManifest(full: StageManifest, state: StageState) -> StageManifest {
        guard let n = state.viewRevision, n >= 1, n < full.revision else { return full }
        return full.atRevision(n)
    }

    /// Like `reduce`, but works from the latest manifest and keeps the state valid when the viewed revision changes
    /// (the selected option or scenario may not exist in an earlier revision). Returns the effects and the manifest to draw.
    public static func apply(_ s: inout StageState, _ action: StageAction, full: StageManifest) -> (effects: [StageEffect], viewed: StageManifest) {
        let before = viewedManifest(full: full, state: s)
        let effects = reduce(&s, action, manifest: before)
        // The latest revision is stored as nil, so a reload that brings a newer one is followed.
        if let n = s.viewRevision, n < 1 || n >= full.revision { s.viewRevision = nil }
        let after = viewedManifest(full: full, state: s)
        if after.revision != before.revision { reconcile(&s, manifest: after) }
        return (effects, after)
    }

    @discardableResult
    public static func reduce(_ s: inout StageState, _ action: StageAction, manifest m: StageManifest) -> [StageEffect] {
        switch action {
        case .setMode(let v): s.mode = v
        case .setAppearance(let v): s.appearance = v
        case .setIncreaseContrast(let v): s.increaseContrast = v
        case .setCorners(let v): s.corners = (v == 26) ? 26 : 10
        case .setTextSize(let v): s.textSize = v
        case .setReduceMotion(let v): s.reduceMotion = v
        case .setZoom(let v): s.zoom = StageZoom.clamp(v)
        case .zoomStep(let up): s.zoom = StageZoom.nextStep(from: s.zoom, up: up)
        case .toggleRedlines: s.redlines.toggle()
        case .setScenario(let id): setScenario(&s, id, m)
        case .nextScenario: nextScenario(&s, m)
        case .selectOption(let id): s.selected = id
        case .stepOption(let d): stepOption(&s, d, m)
        case .flip: flip(&s)
        case .setOverlayOpacity(let v): s.overlayOpacity = min(max(v, 0), 1)
        case .setWipePosition(let v): s.wipePosition = min(max(v, 0), 1)
        case .toggleShown(let id): toggleShown(&s, id, m)
        case .showAllOptions: s.shownOptions = nil
        case .toggleFold(let p):
            if s.foldedPanels.contains(p) { s.foldedPanels.remove(p) } else { s.foldedPanels.insert(p) }
            s.layoutDecided = true
        case .autoFold(let w): autoFold(&s, width: w)
        case .togglePinMode: s.pinMode.toggle()

        case .setControl(let id, let value): s.controlValues[id] = value
        case .applyPreset(let id):
            if let p = m.presets.first(where: { $0.id == id }) {
                var v = m.defaultControlValues
                for (k, x) in p.values { v[k] = x }
                s.controlValues = v
            }
        case .applyRecommendedPreset: s.controlValues = m.recommendedControlValues
        case .resetControls: s.controlValues = m.defaultControlValues

        case .toggleLiveMix: s.showLiveMix.toggle()
        case .pinMix: pinMix(&s, m)
        case .removeMix(let id): s.pinnedMixes.removeAll(where: { $0.id == id })

        case .answer(let topic, let choice): return answer(&s, topic: topic, choice: choice, m)
        case .useRecommendation(let topic):
            guard let rec = m.decision(topic)?.recommended else { return [] }
            return answer(&s, topic: topic, choice: rec, m)
        case .useAllRecommendations:
            var out: [StageEffect] = []
            for d in m.decisions {
                if let rec = d.recommended, s.answers[d.id] != rec { out += answer(&s, topic: d.id, choice: rec, m) }
            }
            return out
        case .usePreview(let topic): return usePreview(&s, topic: topic, m)
        case .useAllPreview:
            var out: [StageEffect] = []
            for d in m.decisions { out += usePreview(&s, topic: d.id, m) }
            return out
        case .setNeedsMore(let topic, let on):
            if on {
                s.needsMore.insert(topic)
                let title = m.decision(topic)?.title ?? topic
                return [.note(kind: "note", body: "[needs more options] \(title): none of the choices fit. Add new options and keep the old ones.")]
            }
            s.needsMore.remove(topic)
        case .setTopicNote(let topic, let text): s.topicNotes[topic] = text
        case .commitTopicNote(let topic): return commitTopicNote(&s, topic, m)
        case .setVerdict(let option, let verdict): return setVerdict(&s, option: option, verdict: verdict, m)
        case .setOptionNote(let option, let text): s.optionNotes[option] = text
        case .commitOptionNote(let option): return commitOptionNote(&s, option, m)
        case .setGeneralNote(let text): s.generalNote = text
        case .commitGeneralNote:
            let t = s.generalNote.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? [] : [.note(kind: "note", body: t)]

        case .addPin(let text, let option, let x, let y): return addPin(&s, text: text, option: option, x: x, y: y)
        case .openPin(let id): openPin(&s, id, m)
        case .removePin(let id):
            if let pin = s.pins.first(where: { $0.id == id }) {
                var hidden = s.hiddenPinKeys ?? []
                let key = StageMerge.pinKey(text: pin.text, option: pin.option)
                if !hidden.contains(key) { hidden.append(key) }
                s.hiddenPinKeys = hidden
            }
            s.pins.removeAll(where: { $0.id == id })

        case .requestAccept: s.sheet = .accept; s.formError = nil
        case .requestSendBack: s.sheet = .sendBack; s.formError = nil
        case .requestAsk: s.sheet = .ask; s.formError = nil
        case .toggleHelp: s.sheet = (s.sheet == .help) ? nil : .help
        case .dismissSheet: s.sheet = nil; s.formError = nil
        case .setSendBackReason(let r): s.sendBackReason = r
        case .setSendBackNote(let t): s.sendBackNote = t; s.formError = nil
        case .setAskDraft(let t): s.askDraft = t
        case .confirmAccept:
            s.sheet = nil
            s.formError = nil
            s.outcome = "Accepted. Hatch is starting the build."
            return [.accept(choices: s.answers)]
        case .confirmSendBack:
            let note = s.sendBackNote.trimmingCharacters(in: .whitespacesAndNewlines)
            if note.isEmpty {
                s.formError = "Write what to change. A note is required."
                return []
            }
            let reason = s.sendBackReason
            s.sheet = nil
            s.formError = nil
            s.sendBackNote = ""
            s.outcome = "Sent back: \(reason.title)."
            return [.sendBack(reason: reason.rawValue, note: note)]
        case .sendAsk:
            let text = s.askDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { s.formError = "Write your question first."; return [] }
            s.sheet = nil
            s.formError = nil
            s.askDraft = ""
            return [.note(kind: "ask", body: text + "\n\n" + describe(s, manifest: m))]
        case .dismissOutcome: s.outcome = nil
        case .setViewRevision(let n): s.viewRevision = n
        case .markRevisionSeen: s.seenRevision = m.revision

        case .togglePlay(let d): s.transport.togglePlay(duration: d)
        case .scrub(let t, let d): s.transport.playing = false; s.transport.scrub(to: t, duration: d)
        case .stepFrames(let n, let d): s.transport.step(frames: n, duration: d)
        case .setSpeed(let v): s.transport.speed = v
        case .toggleLoop: s.transport.loop.toggle()
        case .tick(let dt, let d): s.transport.advance(by: dt, duration: d)

        case .key(let k): return handleKey(&s, k, m)
        }
        return []
    }

    // MARK: Keyboard

    /// The keyboard map: Space flip, arrows switch, 1-5 compare mode, L/D appearance, R redlines, S next scenario,
    /// cmd-Return Accept request, cmd-shift-Return Send back request, ? help. While a sheet is open only `?` is handled.
    static func handleKey(_ s: inout StageState, _ key: StageKey, _ m: StageManifest) -> [StageEffect] {
        if s.sheet != nil {
            if key == .character("?") && s.sheet == .help { s.sheet = nil }
            return []
        }
        switch key {
        case .space: flip(&s)
        case .left: stepOption(&s, -1, m)
        case .right: stepOption(&s, 1, m)
        case .digit(let d):
            if let mode = StageMode.forKey(d) { s.mode = mode }
        case .commandReturn:
            s.sheet = .accept
            s.formError = nil
        case .commandShiftReturn:
            s.sheet = .sendBack
            s.formError = nil
        case .character(let ch):
            let lower = String(ch).lowercased()
            if lower == "l" { s.appearance = .light }
            else if lower == "d" { s.appearance = .dark }
            else if lower == "r" { s.redlines.toggle() }
            else if lower == "s" { nextScenario(&s, m) }
            else if lower == "?" || lower == "/" { s.sheet = .help }
        }
        return []
    }

    // MARK: Looking

    static func flip(_ s: inout StageState) {
        s.mode = .flip
        s.flipSide.toggle()
    }

    static func setScenario(_ s: inout StageState, _ id: String, _ m: StageManifest) {
        guard let sc = m.effectiveScenarios.first(where: { $0.id == id }), sc.applicable else { return }
        s.scenario = id
    }

    static func nextScenario(_ s: inout StageState, _ m: StageManifest) {
        let list = m.applicableScenarios
        guard !list.isEmpty else { return }
        guard let i = list.firstIndex(where: { $0.id == s.scenario }) else {
            s.scenario = list[0].id
            return
        }
        s.scenario = list[(i + 1) % list.count].id
    }

    static func stepOption(_ s: inout StageState, _ delta: Int, _ m: StageManifest) {
        let cols = StageColumns.columns(manifest: m, state: s)
        if let next = StageColumns.step(from: s.selected, by: delta, in: cols) { s.selected = next }
    }

    static func toggleShown(_ s: inout StageState, _ id: String, _ m: StageManifest) {
        let all = m.proposalSpecimens.map { $0.id }
        guard all.contains(id) else { return }
        var shown = s.shownOptions ?? all
        if let i = shown.firstIndex(of: id) {
            if shown.count > 1 { shown.remove(at: i) }
        } else {
            shown.append(id)
        }
        shown = all.filter { shown.contains($0) }
        s.shownOptions = (shown.count == all.count) ? nil : shown
        if let sel = s.selected, all.contains(sel), !shown.contains(sel) { s.selected = shown.first }
    }

    /// Wide windows open both panels, narrow ones fold them; decided once, then the owner's choice stands.
    static func autoFold(_ s: inout StageState, width: Double) {
        guard !s.layoutDecided, width > 0 else { return }
        s.layoutDecided = true
        if width >= 1300 {
            s.foldedPanels.remove(.decision)
            s.foldedPanels.remove(.controls)
            return
        }
        s.foldedPanels.insert(.decision)
        if width < 1000 { s.foldedPanels.insert(.controls) } else { s.foldedPanels.remove(.controls) }
    }

    // MARK: Mix

    static func pinMix(_ s: inout StageState, _ m: StageManifest) {
        let n = StageColumns.nextMixNumber(s.pinnedMixes)
        s.pinnedMixes.append(StageMixColumn(id: "mix.\(n)", title: "Mix \(n)", controls: StageColumns.mixControls(manifest: m, state: s)))
    }

    // MARK: Decisions

    static func answer(_ s: inout StageState, topic: String, choice: String, _ m: StageManifest) -> [StageEffect] {
        if let t = m.exhibitTopic, t.id == topic, m.specimen(choice) != nil {
            return setVerdict(&s, option: choice, verdict: .pick, m, forcePick: true)
        }
        s.answers[topic] = choice
        s.needsMore.remove(topic)
        return [.pick(topic: topic, choice: choice, note: nonEmpty(s.topicNotes[topic]))]
    }

    static func usePreview(_ s: inout StageState, topic: String, _ m: StageManifest) -> [StageEffect] {
        guard let d = m.decision(topic) else { return [] }
        switch d.source {
        case .control:
            let v = s.controlValue(topic, in: m)
            guard !v.isEmpty, d.choices.contains(where: { $0.id == v }) else { return [] }
            if s.answers[topic] == v { return [] }
            return answer(&s, topic: topic, choice: v, m)
        case .specimens:
            let cols = StageColumns.columns(manifest: m, state: s)
            guard let sel = StageColumns.selectedColumn(cols, selected: s.selected), sel.kind == .option else { return [] }
            if s.answers[topic] == sel.specimenID { return [] }
            return answer(&s, topic: topic, choice: sel.specimenID, m)
        case .question:
            return []
        }
    }

    static func commitTopicNote(_ s: inout StageState, _ topic: String, _ m: StageManifest) -> [StageEffect] {
        let text = s.topicNotes[topic]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty { return [] }
        if let choice = s.answers[topic] { return [.pick(topic: topic, choice: choice, note: text)] }
        let title = m.decision(topic)?.title ?? topic
        return [.note(kind: "note", body: "[\(title)] \(text)")]
    }

    /// Pick, Maybe, No on an option. Choosing the same verdict again clears it. A Pick is also the answer to the specimen topic.
    static func setVerdict(_ s: inout StageState, option: String, verdict: StageVerdict, _ m: StageManifest,
                           forcePick: Bool = false) -> [StageEffect] {
        let topic = m.exhibitTopic?.id ?? "exhibit"
        let current = s.verdicts[option]
        let note = nonEmpty(s.optionNotes[option])
        if current == verdict && !forcePick {
            s.verdicts[option] = nil
            if verdict == .pick && s.answers[topic] == option { s.answers[topic] = nil }
            return [.verdict(topic: topic, option: option, verdict: "none", note: note)]
        }
        if current == .pick && verdict != .pick && s.answers[topic] == option { s.answers[topic] = nil }
        s.verdicts[option] = verdict
        if verdict == .pick {
            for (k, v) in s.verdicts where v == .pick && k != option { s.verdicts[k] = nil }
            s.answers[topic] = option
            s.needsMore.remove(topic)
            return [.pick(topic: topic, choice: option, note: note)]
        }
        return [.verdict(topic: topic, option: option, verdict: verdict.rawValue, note: note)]
    }

    static func commitOptionNote(_ s: inout StageState, _ option: String, _ m: StageManifest) -> [StageEffect] {
        let text = s.optionNotes[option]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty { return [] }
        let topic = m.exhibitTopic?.id ?? "exhibit"
        if let v = s.verdicts[option] {
            if v == .pick { return [.pick(topic: topic, choice: option, note: text)] }
            return [.verdict(topic: topic, option: option, verdict: v.rawValue, note: text)]
        }
        let title = m.specimen(option)?.title ?? option
        return [.note(kind: "note", body: "[\(title)] \(text)")]
    }

    // MARK: Pins

    static func addPin(_ s: inout StageState, text: String, option: String?, x: Double?, y: Double?) -> [StageEffect] {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return [] }
        let number = (s.pins.map { $0.number }.max() ?? 0) + 1
        let pin = StagePin(id: "pin.\(number)", number: number, text: t, option: option, x: x, y: y, scenario: s.scenario,
                           appearance: s.appearance, corners: s.corners, zoom: s.zoom)
        s.pins.append(pin)
        let key = StageMerge.pinKey(text: pin.text, option: pin.option)
        if var hidden = s.hiddenPinKeys, hidden.contains(key) {
            hidden.removeAll(where: { $0 == key })
            s.hiddenPinKeys = hidden
        }
        s.pinMode = false
        return [.pin(pin)]
    }

    static func openPin(_ s: inout StageState, _ id: String, _ m: StageManifest) {
        guard let p = s.pins.first(where: { $0.id == id }) else { return }
        s.scenario = p.scenario
        s.appearance = p.appearance
        s.corners = p.corners
        s.zoom = p.zoom
        if let o = p.option, let sp = m.specimen(o), !sp.isEchoToday { s.selected = o }
    }

    // MARK: Loading

    /// After loading a saved state for a manifest: drop what no longer exists, fill what is new.
    public static func reconcile(_ s: inout StageState, manifest m: StageManifest) {
        for (k, v) in m.defaultControlValues where s.controlValues[k] == nil { s.controlValues[k] = v }
        // A choice that does not exist in this revision (an earlier one) falls back to the default.
        for c in m.controls {
            if let v = s.controlValues[c.id], !c.choices.contains(where: { $0.id == v }) { s.controlValues[c.id] = c.defaultChoice }
        }
        let scenarioOK = m.effectiveScenarios.contains(where: { $0.id == s.scenario && $0.applicable })
        if !scenarioOK { s.scenario = m.applicableScenarios.first?.id ?? "rest" }
        let proposals = m.proposalSpecimens.map { $0.id }
        var navigable = proposals + s.pinnedMixes.map { $0.id }
        if s.showLiveMix { navigable.append(StageColumns.liveMixID) }
        let selectedOK = s.selected.map { navigable.contains($0) } ?? false
        if !selectedOK { s.selected = proposals.first }
        if let shown = s.shownOptions {
            let kept = shown.filter { proposals.contains($0) }
            s.shownOptions = kept.isEmpty ? nil : kept
        }
        s.sheet = nil
        s.formError = nil
        s.transport.playing = false
    }

    // MARK: Descriptions

    /// The state in words, sent with a question or a pinned note so the agent sees what the owner saw.
    public static func describe(_ s: StageState, manifest m: StageManifest) -> String {
        let scenario = m.effectiveScenarios.first(where: { $0.id == s.scenario })?.title ?? s.scenario
        var parts: [String] = []
        parts.append("Mode: \(s.mode.title)")
        parts.append("Scenario: \(scenario)")
        parts.append("Appearance: \(s.appearance.title)\(s.increaseContrast ? " + Increase Contrast" : "")")
        parts.append("Corners: \(s.corners)")
        parts.append("Text size: \(s.textSize.title)")
        parts.append("Reduce Motion: \(s.reduceMotion ? "on" : "off")")
        parts.append("Zoom: \(StageZoom.label(scale: s.zoom))")
        if let sel = s.selected, let sp = m.specimen(sel) { parts.append("Option in focus: \(sp.title)") }
        var controls: [String] = []
        for c in m.controls {
            let v = s.controlValue(c.id, in: m)
            let name = c.choices.first(where: { $0.id == v })?.name ?? v
            controls.append("\(c.title) = \(name)")
        }
        if !controls.isEmpty { parts.append("Controls: " + controls.joined(separator: ", ")) }
        return "State on the stage (revision \(m.revision)): " + parts.joined(separator: "; ") + "."
    }

    static func nonEmpty(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }
}

// MARK: - Accept summary

/// What the Accept sheet shows (decision H16).
public struct StageAcceptSummary: Equatable {
    public struct Line: Equatable {
        public var topicID: String
        public var title: String
        public var choice: String
        public var isRecommended: Bool
    }
    public var lines: [Line]
    public var undecided: [String]
    public var repos: [StageAcceptPlan.Repo]
    public var tests: [String]
    public var tokenEstimate: Int

    public static func make(manifest m: StageManifest, state s: StageState) -> StageAcceptSummary {
        var lines: [Line] = []
        var undecided: [String] = []
        for d in m.decisions {
            if let a = s.answers[d.id] {
                lines.append(Line(topicID: d.id, title: d.title, choice: d.choiceName(a), isRecommended: d.recommended == a))
            } else {
                undecided.append(d.title)
            }
        }
        let plan = m.plan ?? StageAcceptPlan()
        let estimate = plan.tokenEstimate ?? heuristicTokens(decisions: lines.count, repos: plan.repos.count)
        return StageAcceptSummary(lines: lines, undecided: undecided, repos: plan.repos, tests: plan.tests, tokenEstimate: estimate)
    }

    /// A rough figure when the Proposal gives none: a base run plus a little per decision and repo.
    public static func heuristicTokens(decisions: Int, repos: Int) -> Int {
        20_000 + decisions * 4_000 + max(repos, 1) * 15_000
    }

    public static func formatTokens(_ n: Int) -> String {
        if n >= 1_000 { return "about \(n / 1_000)k tokens" }
        return "about \(n) tokens"
    }
}
