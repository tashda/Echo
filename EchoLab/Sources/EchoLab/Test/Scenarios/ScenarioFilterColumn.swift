import EchoSenseScenarios
import SwiftUI

/// The left column: progress (how many do what they should, how many you have reviewed, what waits
/// for the agent), then three filters that combine: result, your review and area. Each count says how
/// many you would see if you picked that row, with the other two filters as they are.
struct ScenarioFilterColumn: View {
    let store: ScenarioStore
    @Binding var filters: ScenarioFilters

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
                Section("Area") {
                    row("All areas", symbol: "square.grid.2x2", tint: ColorTokens.Text.secondary, filter: \.area, value: nil)
                    ForEach(store.groups, id: \.self) { group in
                        row(group, symbol: isReviewed(group) ? "checkmark.seal.fill" : "circle.dotted",
                            tint: isReviewed(group) ? ColorTokens.Status.success : ColorTokens.Text.tertiary, filter: \.area, value: group)
                            .help(isReviewed(group) ? "You have reviewed every scenario here" : "\(unreviewed(group)) not reviewed yet")
                    }
                }
            }
            .listStyle(.sidebar)
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
            if waiting.flagged + waiting.toFix > 0 {
                Label("For the agent: \(waiting.flagged) to change, \(waiting.toFix) to fix in EchoSense", systemImage: "arrow.turn.up.right")
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
