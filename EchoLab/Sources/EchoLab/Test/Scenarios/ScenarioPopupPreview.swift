import EchoSenseScenarios
import SwiftUI

/// The SQL with its caret and, under the caret, the completion popup as the editor would show it:
/// expected items ticked, forbidden ones marked, expected items that are missing as struck-out ghost rows.
struct ScenarioPopupPreview: View {
    let scenario: CompletionScenario
    let actual: ScenarioActual?

    private static let visibleRows = 12

    var body: some View {
        let (text, caret) = scenario.textAndCaret
        let ns = text as NSString
        let before = ns.substring(to: min(caret, ns.length)), after = ns.substring(from: min(caret, ns.length))
        let caretLine = before.components(separatedBy: "\n").last ?? ""
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            Text("\(before)\(Text("▏").foregroundStyle(ColorTokens.accent).fontWeight(.bold))\(after)")
                .font(TypographyTokens.code).textSelection(.enabled)
            if let steps { Text(steps).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary) }
            HStack(alignment: .top, spacing: 0) {
                // The popup starts under the caret; a long line pushes it at most this far.
                Text(caretLine).font(TypographyTokens.code).lineLimit(1).hidden().frame(maxWidth: 360, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                popup
            }
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.Surface.rest, in: .rect(cornerRadius: 10))
    }

    private var steps: String? {
        guard let accepted = scenario.afterAccepting else { return nil }
        var text = "First accepts " + (accepted.isEmpty ? "the first suggestion" : "“\(accepted)”")
        if let typed = scenario.thenTyped, !typed.isEmpty { text += ", then types “\(typed.replacingOccurrences(of: " ", with: "␣"))”" }
        return text + ". The popup below is what comes next."
    }

    @ViewBuilder
    private var popup: some View {
        if let actual {
            if actual.titles.isEmpty && missing(in: actual).isEmpty {
                closedNote(actual)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(actual.titles.prefix(Self.visibleRows).enumerated()), id: \.offset) { _, title in row(title, actual: actual) }
                    if actual.titles.count > Self.visibleRows {
                        Text("and \(actual.titles.count - Self.visibleRows) more").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                            .padding(.horizontal, SpacingTokens.xxs2)
                    }
                    ForEach(missing(in: actual), id: \.self) { ghost($0) }
                    if actual.titles.isEmpty { closedNote(actual).padding(.top, SpacingTokens.xxs) }
                }
                .padding(SpacingTokens.xxxs)
                .frame(minWidth: 220, alignment: .leading)
                .fixedSize()
                .labCard(cornerRadius: 8)
            }
        }
    }

    private func row(_ title: String, actual: ScenarioActual) -> some View {
        let plain = CompletionScenarioRunner.unquoted(title)
        let forbidden = scenario.echoSense?.excludes.contains(plain) == true
        let expected = scenario.echoSense?.items.contains(plain) == true
        let tint = forbidden ? ColorTokens.Status.error : (expected ? ColorTokens.Status.success : ColorTokens.Text.primary)
        return HStack(spacing: SpacingTokens.xxs2) {
            Image(systemName: forbidden ? "nosign" : (expected ? "checkmark" : "circle.fill"))
                .font(TypographyTokens.label).frame(width: 12).opacity(forbidden || expected ? 1 : 0)
            Text(title).font(TypographyTokens.code)
            Spacer(minLength: SpacingTokens.md)
            if let insert = actual.insertText[title], insert != title {
                Text("→ \(insert)").font(TypographyTokens.detailMono).foregroundStyle(ColorTokens.Text.tertiary)
            }
            Text(actual.kinds[title] ?? "").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, SpacingTokens.xxs2).padding(.vertical, SpacingTokens.xxxs)
        .background(forbidden ? ColorTokens.Status.error.opacity(0.12) : (expected ? ColorTokens.Status.success.opacity(0.12) : .clear),
                    in: .rect(cornerRadius: 5))
    }

    private func ghost(_ title: String) -> some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Image(systemName: "xmark").font(TypographyTokens.label).frame(width: 12)
            Text(title).font(TypographyTokens.code).strikethrough()
            Spacer(minLength: SpacingTokens.md)
            Text("expected").font(TypographyTokens.detail)
        }
        .foregroundStyle(ColorTokens.Status.error)
        .padding(.horizontal, SpacingTokens.xxs2).padding(.vertical, SpacingTokens.xxxs)
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(ColorTokens.Status.error.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
    }

    private func closedNote(_ actual: ScenarioActual) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("No popup").font(TypographyTokens.standard.weight(.medium))
            if !actual.engineTitles.isEmpty {
                Text("EchoSense has \(actual.engineTitles.count) suggestions, but the editor doesn't ask here. \(actual.triggerNote)")
            } else if scenario.trigger == .typing, !actual.manualTitles.isEmpty {
                Text("By hand (⌘.) it would offer \(actual.manualTitles.prefix(6).joined(separator: ", "))\(actual.manualTitles.count > 6 ? " and more" : "").")
            }
        }
        .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
        .padding(SpacingTokens.xs).frame(maxWidth: 320, alignment: .leading)
        .labCard(cornerRadius: 8)
    }

    /// Expected titles the popup doesn't have.
    private func missing(in actual: ScenarioActual) -> [String] {
        guard let expected = scenario.echoSense, expected.outcome == .suggests else { return [] }
        let offered = Set(actual.titles.map(CompletionScenarioRunner.unquoted))
        return expected.items.filter { !offered.contains($0) }
    }
}
