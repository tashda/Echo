import SwiftUI

/// A finished round, replayed: what it showed, what you were asked, what you decided, and the
/// playground as you saw it (live, scaled to fit).
struct LabDecisionView: View {
    let decision: LabDecision

    /// The original Design Lab page each decision came from, for its introduction and questions.
    private static let legacyPages: [String: DesignLabPage] = [
        "round9-footer-scroller-tabs": .round9, "round10-footer-and-switcher": .round10,
        "round11-tab-bar": .round11, "round12-two-line-tabs": .round12, "round13-tab-directions": .round13,
        "tree-card-s4-quiet": .treeCard, "window-canvas-and-cards": .window, "rail-servers": .rail,
        "tree-sticky-header": .tree, "results-grid": .results, "toasts-and-notifications": .floating,
        "inspector-column": .inspector,
    ]

    private var legacy: DesignLabPage? { Self.legacyPages[decision.id] }
    private var info: LabRounds.Info? { LabRounds.info(forPage: "decided.\(decision.id)") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                header
                if let legacy { saw(legacy) }
                asked
                decided
                howItLooked
            }
            .padding(SpacingTokens.lg)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text("\(info.map { "\($0.label) · \($0.date)" } ?? "Decided \(decision.decidedOn)")")
                .font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
            Text(decision.question).font(TypographyTokens.title3.weight(.semibold))
            if let replacement = decision.supersededBy {
                Label("Superseded by \(replacement)", systemImage: "arrow.triangle.swap")
                    .font(TypographyTokens.standard).foregroundStyle(ColorTokens.Status.warning)
            }
        }
    }

    private func saw(_ page: DesignLabPage) -> some View {
        section("What the page said") {
            Text(page.intro).font(TypographyTokens.standard).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var asked: some View {
        if let legacy, !legacy.questions.isEmpty {
            section("What you were asked") {
                ForEach(legacy.questions) { question in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(question.title).font(TypographyTokens.standard.weight(.semibold))
                        Text(question.howTo).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                        HStack(spacing: SpacingTokens.xxs) {
                            ForEach(question.options, id: \.self) { option in
                                Text(option).font(TypographyTokens.detail)
                                    .padding(.horizontal, SpacingTokens.xs).padding(.vertical, 2)
                                    .background(ColorTokens.Surface.hover, in: Capsule())
                            }
                        }
                    }
                }
            }
        }
    }

    private var decided: some View {
        section("What you decided") {
            Text(decision.reasoning).font(TypographyTokens.standard).fixedSize(horizontal: false, vertical: true)
            if !decision.shipped.isEmpty {
                Text("In Echo: " + decision.shipped.joined(separator: ", "))
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    private var howItLooked: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("How it looked").font(TypographyTokens.title3.weight(.semibold))
            Text("The playground exactly as you tried it, live. It is scaled to fit this window.")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            ForEach(decision.options) { option in
                LabDecisionOptionView(option: option)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(title).font(TypographyTokens.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: SpacingTokens.sm) { content() }
                .padding(SpacingTokens.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.Surface.rest, in: .rect(cornerRadius: 12, style: .continuous))
        }
    }
}
