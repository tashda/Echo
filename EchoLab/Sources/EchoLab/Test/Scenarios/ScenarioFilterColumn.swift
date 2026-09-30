import EchoSenseScenarios
import SwiftUI

/// The left column: how many scenarios do what they should, then filters by result, by the owner's
/// review and by area, each with its count.
struct ScenarioFilterColumn: View {
    let store: ScenarioStore
    @Binding var filter: ScenarioFilter

    var body: some View {
        VStack(spacing: 0) {
            progress.padding(SpacingTokens.sm)
            Divider()
            List(selection: Binding(get: { filter }, set: { if let new = $0 { filter = new } })) {
                Section("Result") {
                    row(.all, "All", symbol: "tray.full", tint: ColorTokens.Text.secondary)
                    ForEach(ScenarioOutcome.allCases, id: \.self) { outcome in
                        if outcome == .wrong || outcome == .right || store.count(.outcome(outcome)) > 0 {
                            row(.outcome(outcome), outcome.title, symbol: outcome.symbol, tint: outcome.tint)
                        }
                    }
                }
                Section("Your review") {
                    ForEach(ScenarioReview.allCases, id: \.self) { review in
                        row(.review(review), review.title, symbol: review.symbol, tint: ColorTokens.Text.secondary)
                    }
                }
                Section("Area") {
                    ForEach(store.groups, id: \.self) { group in areaRow(group) }
                }
            }
            .listStyle(.sidebar)
        }
    }

    private var progress: some View {
        let right = store.count(.outcome(.right)), wrong = store.count(.outcome(.wrong)), total = max(store.scenarios.count, 1)
        return VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xxs) {
                Text("\(right) of \(store.scenarios.count)").font(TypographyTokens.statNumber)
                Text("do what they should").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    ColorTokens.Status.success.frame(width: proxy.size.width * CGFloat(right) / CGFloat(total))
                    ColorTokens.Status.error.frame(width: proxy.size.width * CGFloat(wrong) / CGFloat(total))
                    ColorTokens.Surface.hover
                }
            }
            .frame(height: SpacingTokens.xxs2).clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ value: ScenarioFilter, _ title: String, symbol: String, tint: Color) -> some View {
        HStack {
            Label { Text(title) } icon: { Image(systemName: symbol).foregroundStyle(tint) }
            Spacer()
            Text("\(store.count(value))").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.secondary)
        }
        .tag(value)
    }

    private func areaRow(_ group: String) -> some View {
        let wrong = store.count(.wrong, in: group)
        return HStack {
            Text(group).lineLimit(1)
            Spacer()
            if wrong > 0 {
                Text("\(wrong)").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Status.error)
            }
            Text("\(store.count(.area(group)))").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.tertiary)
        }
        .help(wrong > 0 ? "\(wrong) wrong" : "All right")
        .tag(ScenarioFilter.area(group))
    }
}
