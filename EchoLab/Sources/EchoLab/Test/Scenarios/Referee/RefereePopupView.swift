import EchoSenseScenarios
import SwiftUI

/// "What EchoSense does": the real popup row by row, each with its place, its kind in words and where
/// it comes from ("users · table · in public"). After the call, each row says which group of the
/// rule it belongs to, or what is wrong with it.
struct RefereePopupView: View {
    let scenario: CompletionScenario
    let result: ScenarioResult?
    let revealed: Bool

    @State private var showsAll = false
    private static let firstRows = 14

    var body: some View {
        if let actual = result?.actual {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                if actual.rows.isEmpty {
                    VStack(spacing: SpacingTokens.xxs) {
                        Text("NO POPUP").font(TypographyTokens.headline)
                        Text(actual.triggerNote).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).multilineTextAlignment(.center)
                        if !actual.manualTitles.isEmpty {
                            Text("Asked by hand (⌘.): \(actual.manualTitles.count) suggestions, \(actual.manualTitles.prefix(6).joined(separator: ", "))…")
                                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary).multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(SpacingTokens.md)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ColorTokens.Text.tertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                } else {
                    let notes = revealed ? rowNotes(actual.rows) : [:]
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(actual.rows.prefix(showsAll ? actual.rows.count : Self.firstRows).enumerated()), id: \.offset) { index, row in
                            rowView(index, row, note: notes[index])
                        }
                    }
                    .padding(SpacingTokens.xxxs).labCard(cornerRadius: 10)
                    if actual.rows.count > Self.firstRows {
                        Button(showsAll ? "Show the first \(Self.firstRows)" : "Show all \(actual.rows.count)") { showsAll.toggle() }.buttonStyle(.borderless)
                    }
                }
                if let after = actual.textAfterAccepting {
                    Text("Accepting the first suggestion gives `\(after)`").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).textSelection(.enabled)
                }
            }
        } else {
            Text("Not run.").foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    private func rowView(_ index: Int, _ row: ScenarioActual.Row, note: (text: String, tint: Color)?) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Text("\(index + 1)").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.tertiary).frame(width: 22, alignment: .trailing)
            ScenarioKindPill(kind: row.kind)
            Text(row.title).font(TypographyTokens.code).lineLimit(1)
            if let origin = result?.resolver?.origin(title: row.title, kind: row.kind), !origin.isEmpty {
                Text(origin).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary).lineLimit(1)
            }
            Spacer(minLength: SpacingTokens.xs)
            if let note { Text(note.text).font(TypographyTokens.detail.weight(.medium)).foregroundStyle(note.tint) }
        }
        .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxxs)
        .background((note?.tint ?? .clear).opacity(note == nil ? 0 : 0.1), in: .rect(cornerRadius: 6))
        .help(row.insertText != row.title ? "Inserts \(row.insertText)" : "")
    }

    /// Per row: its group in the rule, or why it shouldn't be there.
    private func rowNotes(_ rows: [ScenarioActual.Row]) -> [Int: (text: String, tint: Color)] {
        guard let popup = scenario.popup, let resolver = result?.resolver, scenario.echoSense?.outcome ?? .suggests == .suggests else {
            return [:]
        }
        var notes: [Int: (String, Color)] = [:]
        var seen = Set<String>()
        for (index, row) in rows.enumerated() {
            let key = CompletionScenarioRunner.unquoted(row.title).lowercased()
            if !seen.insert(key).inserted { notes[index] = ("offered twice", ColorTokens.Status.error); continue }
            if popup.never.contains(where: { resolver.matches(title: row.title, kind: row.kind, block: $0) }) { notes[index] = ("never allowed", ColorTokens.Status.error); continue }
            if let group = popup.groups.firstIndex(where: { resolver.matches(title: row.title, kind: row.kind, block: $0.block, typed: $0.typed) }) {
                notes[index] = ("\(PopupResolver.ordinal(group)) group", ColorTokens.Status.success)
            } else {
                notes[index] = popup.rest == .none ? ("not in the rule", ColorTokens.Status.error) : ("other", ColorTokens.Text.tertiary)
            }
        }
        return notes
    }
}
