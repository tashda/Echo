import EchoSenseScenarios
import SwiftUI

/// The left column: progress (how many do what they should, how many you have reviewed, what waits
/// for the agent), then three filters that combine: result, your review and area. Each count says how
/// many you would see if you picked that row, with the other two filters as they are.
struct ScenarioFilterColumn: View {
    let store: ScenarioStore
    @Binding var filters: ScenarioFilters
    /// The scenario "New area" moves.
    let selectedID: String?

    @State private var editingRule: ScenarioRule?
    @State private var namingArea: String?
    @State private var areaName = ""

    var body: some View {
        VStack(spacing: 0) {
            progress.padding(SpacingTokens.sm)
            Divider()
            List {
                Section("Result") {
                    row("All results", symbol: "tray.full", tint: ColorTokens.Text.secondary, filter: \.outcome, value: nil)
                    ForEach(ScenarioOutcome.allCases, id: \.self) { outcome in
                        if outcome == .wrong || outcome == .right || store.count(ScenarioFilters(outcome: outcome)) > 0 {
                            row(outcome.title, symbol: outcome.symbol, tint: outcome.tint, filter: \.outcome, value: outcome)
                        }
                    }
                }
                Section("Your review") {
                    row("Reviewed or not", symbol: "tray.full", tint: ColorTokens.Text.secondary, filter: \.review, value: nil)
                    ForEach(ScenarioReview.allCases, id: \.self) { review in
                        row(review.title, symbol: review.symbol, tint: ColorTokens.Text.secondary, filter: \.review, value: review)
                    }
                }
                Section("Feedback") {
                    row("Any", symbol: "bubble.left.and.bubble.right", tint: ColorTokens.Text.secondary, filter: \.thread, value: nil)
                    ForEach(ScenarioThreadState.allCases, id: \.self) { state in
                        row(state.title, symbol: state.symbol, tint: ColorTokens.accent, filter: \.thread, value: state)
                    }
                }
                Section("Area") {
                    row("All areas", symbol: "square.grid.2x2", tint: ColorTokens.Text.secondary, filter: \.area, value: nil)
                    ForEach(store.groups, id: \.self) { group in
                        row(group, symbol: isReviewed(group) ? "checkmark.seal.fill" : "circle.dotted",
                            tint: isReviewed(group) ? ColorTokens.Status.success : ColorTokens.Text.tertiary, filter: \.area, value: group)
                            .help(isReviewed(group) ? "You have reviewed every scenario here. Drop a scenario here to move it." : "\(unreviewed(group)) not reviewed yet. Drop a scenario here to move it.")
                            .dropDestination(for: String.self) { texts, _ in
                                if case .scenario(let id)? = ScenarioDragItem.first(in: texts) { store.move(id, toArea: group) }
                            }
                    }
                    Button("New area", systemImage: "plus") { namingArea = selectedID; areaName = "" }
                        .buttonStyle(.borderless).disabled(selectedID == nil)
                        .help("Moves the selected scenario into a new area. You can also drop a scenario here.")
                        .dropDestination(for: String.self) { texts, _ in
                            if case .scenario(let id)? = ScenarioDragItem.first(in: texts) { namingArea = id; areaName = "" }
                        }
                }
                Section("Rules") {
                    row("Any", symbol: "link", tint: ColorTokens.Text.secondary, filter: \.rule, value: nil)
                    ForEach(store.ruleLibrary.rules) { rule in
                        row(rule.title, symbol: "link", tint: ColorTokens.accent, filter: \.rule, value: rule.id)
                            .help("\(rule.id): \(rule.should.isEmpty ? rule.title : rule.should)\nDrop a scenario here to make it follow this rule; drag the rule onto a scenario to do the same.")
                            .draggable(ScenarioDragItem.rule(rule.id).text)
                            .dropDestination(for: String.self) { texts, _ in
                                if case .scenario(let id)? = ScenarioDragItem.first(in: texts) { store.setFollows(rule.id, true, scenario: id) }
                            }
                            .contextMenu {
                                Button("Edit rule") { editingRule = rule }
                                Button("Delete rule", role: .destructive) { store.deleteRule(rule.id) }
                            }
                    }
                    Button("New rule", systemImage: "plus") { editingRule = store.addRule(title: "New rule") }
                        .buttonStyle(.borderless)
                }
            }
            .listStyle(.sidebar)
            .sheet(item: $editingRule) { rule in ScenarioRuleEditor(rule: rule, store: store) }
            .alert("New area", isPresented: Binding(get: { namingArea != nil }, set: { if !$0 { namingArea = nil } })) {
                TextField("", text: $areaName, prompt: Text("Area name, e.g. Lateral joins"))
                Button("Move here") { if let id = namingArea { store.move(id, toArea: areaName); filters.area = areaName } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The scenario moves into it. An area is a file of scenarios in EchoSense.")
            }
            if filters != .reviewQueue {
                Divider()
                Button("Show what's left to review", systemImage: "arrow.uturn.backward") { filters = .reviewQueue }
                    .buttonStyle(.borderless).padding(SpacingTokens.xs).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var progress: some View {
        let total = max(store.scenarios.count, 1)
        let right = store.count(ScenarioFilters(outcome: .right)), wrong = store.count(ScenarioFilters(outcome: .wrong))
        let reviewed = store.scenarios.count - store.count(ScenarioFilters(review: .imported))
        let waiting = store.waitingForAgent
        return VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            meter("\(right) of \(store.scenarios.count)", "do what they should",
                  [(ColorTokens.Status.success, right), (ColorTokens.Status.error, wrong)], total: total)
            meter("\(reviewed) of \(store.scenarios.count)", "reviewed by you", [(ColorTokens.accent, reviewed)], total: total)
            if waiting.messages + waiting.flagged + waiting.toFix > 0 {
                Label("For the agent: \(waiting.messages) messages, \(waiting.flagged) to change, \(waiting.toFix) to fix in EchoSense", systemImage: "arrow.turn.up.right")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    .help("Tell the agent “work through my scenario reviews”. It finds them with lab-inbox.py.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func meter(_ value: String, _ label: String, _ parts: [(Color, Int)], total: Int) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xxs) {
                Text(value).font(TypographyTokens.headline)
                Text(label).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                        part.0.frame(width: proxy.size.width * CGFloat(part.1) / CGFloat(total))
                    }
                    ColorTokens.Surface.hover
                }
            }
            .frame(height: SpacingTokens.xxs2).clipShape(Capsule())
        }
    }

    /// One choice in a section; picking it changes only that section's filter.
    private func row<Value: Equatable>(_ title: String, symbol: String, tint: Color,
                                       filter keyPath: WritableKeyPath<ScenarioFilters, Value?>, value: Value?) -> some View {
        var candidate = filters
        candidate[keyPath: keyPath] = value
        let isOn = filters[keyPath: keyPath] == value
        return Button { filters = candidate } label: {
            HStack {
                Label { Text(title).lineLimit(1) } icon: { Image(systemName: symbol).foregroundStyle(isOn ? ColorTokens.Text.onFill : tint) }
                Spacer()
                Text("\(store.count(candidate))").font(TypographyTokens.detail.monospacedDigit())
                    .foregroundStyle(isOn ? ColorTokens.Text.onFill : ColorTokens.Text.secondary)
            }
            .foregroundStyle(isOn ? ColorTokens.Text.onFill : ColorTokens.Text.primary)
            .padding(.horizontal, SpacingTokens.xxs2).padding(.vertical, SpacingTokens.xxxs)
            .background(isOn ? ColorTokens.accent : .clear, in: .rect(cornerRadius: 6))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: SpacingTokens.xxs, bottom: 0, trailing: SpacingTokens.xxs))
    }

    private func unreviewed(_ group: String) -> Int { store.library.scenarios(in: group).count { $0.review == .imported } }
    private func isReviewed(_ group: String) -> Bool { unreviewed(group) == 0 }
}
