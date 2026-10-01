import EchoSenseScenarios
import SwiftUI

/// Test › Popup Referee: the scenarios as a game against the live engine. Each round shows the SQL
/// and what the scenario reads from it, the rule ("what it needs to do", built from blocks), then,
/// after Space, the real popup with every row's kind. Y or N says whether the popup follows the rule;
/// the checks decide, and score it. E changes the rule (saved to the scenario file); feedback goes to
/// the scenario's thread for the agent.
struct RefereePage: View {
    @State private var store = ScenarioStore.shared
    @AppStorage("lab.referee.current") private var currentID = ""
    @AppStorage("lab.referee.area") private var area = ""
    @State private var phase = Phase.rule
    @State private var saidFollows: Bool?
    @State private var score = 0
    @State private var streak = 0
    @State private var draft: CompletionScenario?
    @State private var draftResult: ScenarioResult?
    @State private var message = ""
    @FocusState private var focused: Bool

    enum Phase { case rule, call, verdict }

    private var queue: [CompletionScenario] { store.scenarios.filter { area.isEmpty || $0.group == area } }
    private var saved: CompletionScenario? { queue.first { $0.id == currentID } ?? queue.first }
    private var shown: CompletionScenario? { draft ?? saved }
    private var result: ScenarioResult? { draft != nil ? draftResult : saved.flatMap { store.result(for: $0.id) } }
    /// Whether the popup follows the rule; nil when there is no rule to judge by.
    private var follows: Bool? {
        guard let result else { return nil }
        if case .unchecked = result.verdict { return nil }
        return !result.isFailing
    }

    var body: some View {
        VStack(spacing: 0) {
            RefereeScoreboard(position: (queue.firstIndex { $0.id == saved?.id } ?? 0) + 1, count: queue.count, score: score, streak: streak,
                              areas: store.groups, area: $area)
            Divider()
            if let scenario = shown {
                ScrollView {
                    round(scenario).padding(SpacingTokens.md).frame(maxWidth: 1200, alignment: .leading).frame(maxWidth: .infinity)
                }
            } else {
                LabMailEmpty(title: "No scenarios", symbol: "checklist")
            }
        }
        .focusable().focusEffectDisabled().focused($focused)
        .onAppear { focused = true; if saved != nil, currentID.isEmpty { currentID = saved?.id ?? "" } }
        .onChange(of: area) { _, _ in currentID = queue.first?.id ?? ""; restartRound() }
        .onChange(of: draft) { _, new in draftResult = new.map { store.runner.run($0) } }
        .onKeyPress(.space) {
            guard phase == .rule else { return .ignored }
            run()
            return .handled
        }
        .onKeyPress("y") { judge(true); return .handled }
        .onKeyPress("n") { judge(false); return .handled }
        .onKeyPress("e") { toggleEditing(); return .handled }
        .onKeyPress(.return) {
            guard phase == .verdict else { return .ignored }
            next()
            return .handled
        }
    }

    // MARK: Round

    private func round(_ scenario: CompletionScenario) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack(spacing: SpacingTokens.xxs2) {
                LabTag(text: scenario.id); LabTag(text: scenario.group); LabTag(text: scenario.dialect.title)
                LabTag(text: scenario.trigger == .typing ? "While typing" : "Asked by hand (⌘.)")
            }
            Text(scenario.title).font(TypographyTokens.title.weight(.bold))
            sql(scenario)
            if let context = result?.resolver { RefereeContextLine(resolver: context) }
            HStack(alignment: .top, spacing: SpacingTokens.md) {
                side("What it needs to do", tint: ColorTokens.accent) {
                    HStack {
                        Spacer()
                        if draft != nil {
                            Button("Cancel") { draft = nil }.buttonStyle(LabPillButtonStyle())
                            Button("Save the rule", systemImage: "checkmark") { if let draft { store.update(draft) }; draft = nil }
                                .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, prominent: true))
                        } else {
                            Button("Change the rule (E)", systemImage: "slider.horizontal.3") { toggleEditing() }.buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent))
                        }
                    }
                    if draft != nil {
                        RefereeRuleBuilder(scenario: Binding(get: { draft ?? scenario }, set: { draft = $0 }), resolver: result?.resolver)
                    }
                    RefereeRuleView(scenario: scenario, resolver: result?.resolver, offered: phase == .verdict ? offeredTitles : nil)
                }
                side("What EchoSense does", tint: ColorTokens.Text.secondary) {
                    if phase == .rule {
                        VStack(spacing: SpacingTokens.xs) {
                            Button("Run EchoSense (Space)", systemImage: "play.fill") { run() }.buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, prominent: true))
                            Text("Get the rule right first. Then see the real popup.").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 160)
                    } else {
                        RefereePopupView(scenario: scenario, result: result, revealed: phase == .verdict)
                    }
                }
            }
            if phase == .call { callBar }
            if phase == .verdict { RefereeVerdict(follows: follows, said: saidFollows, result: result, message: $message, send: send, next: next) }
        }
    }

    private func sql(_ scenario: CompletionScenario) -> some View {
        let (text, caret) = scenario.textAndCaret
        let ns = text as NSString
        let before = ns.substring(to: min(caret, ns.length)), after = ns.substring(from: min(caret, ns.length))
        return Text("\(before)\(Text("▏").foregroundStyle(ColorTokens.accent).fontWeight(.heavy))\(after)")
            .font(TypographyTokens.code).textSelection(.enabled)
            .padding(SpacingTokens.sm).frame(maxWidth: .infinity, alignment: .leading).labField(cornerRadius: 10)
    }

    private func side<Content: View>(_ title: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text(title.uppercased()).font(TypographyTokens.headline).foregroundStyle(tint)
            content()
        }
        .padding(SpacingTokens.sm).frame(maxWidth: .infinity, alignment: .topLeading).labCard(cornerRadius: 14)
    }

    private var callBar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Button("It follows the rule (Y)", systemImage: "checkmark") { judge(true) }.buttonStyle(LabPillButtonStyle(tint: ColorTokens.Status.success, prominent: true))
            Button("It breaks it (N)", systemImage: "xmark") { judge(false) }.buttonStyle(LabPillButtonStyle(tint: ColorTokens.Status.error, prominent: true))
            Text("Go row by row: is each row in the right group, in the right place? Is anything there that shouldn't be?")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
        }
        .controlSize(.large)
    }

    private var offeredTitles: Set<String> {
        Set((result?.actual?.rows ?? []).map { CompletionScenarioRunner.unquoted($0.title).lowercased() })
    }

    // MARK: Actions

    private func run() { if phase == .rule { phase = .call } }

    private func judge(_ saysFollows: Bool) {
        guard phase == .call else { return }
        saidFollows = saysFollows
        if let follows, follows == saysFollows { streak += 1; score += 100 * (2 + min(streak - 1, 4)) / 2 } else if follows != nil { streak = 0 }
        phase = .verdict
    }

    private func next() {
        guard let index = queue.firstIndex(where: { $0.id == saved?.id }), index + 1 < queue.count else { return }
        currentID = queue[index + 1].id
        restartRound()
    }

    private func restartRound() { phase = .rule; saidFollows = nil; draft = nil; message = ""; focused = true }

    private func toggleEditing() { draft = draft == nil ? saved : nil }

    private func send() {
        guard let id = saved?.id else { return }
        store.comment(message, about: nil, on: id)
        message = ""
        focused = true
    }
}
