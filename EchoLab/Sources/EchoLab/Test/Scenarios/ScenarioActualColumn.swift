import EchoSenseScenarios
import SwiftUI

/// The popup as EchoSense returns it now, every row: its place, kind and priority. Rows can be dragged
/// into the expectation on the left, or added with the buttons on each row.
struct ScenarioActualColumn: View {
    @Binding var scenario: CompletionScenario
    let actual: ScenarioActual?

    @State private var showsAll = false
    private static let firstRows = 25

    var body: some View {
        LabReadingCard(title: "The popup now", symbol: "list.number") {
            if let actual {
                facts(actual)
                if actual.titles.isEmpty {
                    Text(actual.popupShown ? "Nothing offered." : "No popup.").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                    if !actual.engineTitles.isEmpty {
                        Text("If asked anyway: \(actual.engineTitles.prefix(10).joined(separator: ", "))")
                            .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    }
                } else {
                    Text("Drag a row to the left, or use + (expected) and ⊘ (never offers).")
                        .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    let shown = showsAll ? actual.titles : Array(actual.titles.prefix(Self.firstRows))
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(shown.enumerated()), id: \.offset) { index, title in row(index + 1, title, actual) }
                    }
                    if actual.titles.count > Self.firstRows {
                        Button(showsAll ? "Show the first \(Self.firstRows)" : "Show all \(actual.titles.count)") { showsAll.toggle() }
                            .buttonStyle(.borderless)
                    }
                }
            } else {
                Text("Not run.").foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    private func facts(_ actual: ScenarioActual) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Caret in \(actual.clause) · token “\(actual.token)” · \(actual.titles.count) offered")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            Text(actual.triggerNote).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            if let after = actual.textAfterAccepting {
                Text("Accepting the first gives: \(after)").font(TypographyTokens.detailMono).foregroundStyle(ColorTokens.Text.tertiary).lineLimit(2)
            }
        }
    }

    private func row(_ rank: Int, _ title: String, _ actual: ScenarioActual) -> some View {
        let plain = CompletionScenarioRunner.unquoted(title)
        let expectedAt = scenario.echoSense?.items.firstIndex(of: plain)
        let forbidden = scenario.echoSense?.excludes.contains(plain) == true
        return HStack(spacing: SpacingTokens.xs) {
            Text("\(rank)").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.tertiary).frame(width: 24, alignment: .trailing)
            Text(title).font(TypographyTokens.code)
                .foregroundStyle(forbidden ? ColorTokens.Status.error : (expectedAt != nil ? ColorTokens.Status.success : ColorTokens.Text.primary))
            if let expectedAt {
                Text("expected #\(expectedAt + 1)").font(TypographyTokens.detail)
                    .foregroundStyle(expectedAt + 1 == rank ? ColorTokens.Status.success : ColorTokens.Status.error)
            }
            Spacer()
            Text(actual.kinds[title].map(ScenarioKinds.name) ?? "").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            if let priority = actual.priorities[title] {
                Text("p\(priority)").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.tertiary)
                    .help("EchoSense's priority; higher ranks earlier")
            }
            Button("Expect", systemImage: "plus") { expect(plain) }.labelStyle(.iconOnly).buttonStyle(.borderless)
                .help("Add to the expected titles, at the end")
            Button("Never offers", systemImage: "nosign") { forbid(plain) }.labelStyle(.iconOnly).buttonStyle(.borderless)
                .help("Must never be offered here")
        }
        .padding(.horizontal, SpacingTokens.xxs).padding(.vertical, 1)
        .contentShape(.rect)
        .draggable(ScenarioDragItem.suggestion(plain).text)
    }

    private func expect(_ title: String) {
        var value = scenario.echoSense ?? EchoSenseExpectation(outcome: .suggests)
        value.outcome = .suggests
        value.excludes.removeAll { $0 == title }
        if !value.items.contains(title) { value.items.append(title) }
        scenario.echoSense = value
    }

    private func forbid(_ title: String) {
        var value = scenario.echoSense ?? EchoSenseExpectation(outcome: .suggests)
        value.items.removeAll { $0 == title }
        if !value.excludes.contains(title) { value.excludes.append(title) }
        scenario.echoSense = value
    }
}
