import SwiftUI

/// The text of a fast round: what the owner said, what the agent found, what it suggests and
/// what would change. Read from the store, so an agent's edits show as they are saved.
struct FastRoundBody: View {
    let pageID: String

    var body: some View {
        if let round = FastRoundStore.shared.round(forPage: pageID) {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                if !round.summary.isEmpty {
                    LabReadingCard(title: "In short", symbol: "text.alignleft") { FastRoundText(round.summary, font: TypographyTokens.prominent) }
                }
                LabReadingCard(title: "Your feedback", symbol: "text.bubble") { FastRoundText(round.feedback) }
                ForEach(Array(round.analysis.enumerated()), id: \.offset) { _, section in
                    LabReadingCard(title: section.heading, symbol: "magnifyingglass") { FastRoundText(section.body) }
                }
                if !round.recommendation.isEmpty {
                    LabReadingCard(title: "What I suggest", symbol: "lightbulb") { FastRoundText(round.recommendation) }
                }
                if !round.changes.isEmpty {
                    LabReadingCard(title: "What changes in Echo if you accept", symbol: "hammer") {
                        ForEach(Array(round.changes.enumerated()), id: \.offset) { _, change in
                            Label { FastRoundText(change) } icon: { Image(systemName: "smallcircle.filled.circle").font(.system(size: 6)).foregroundStyle(ColorTokens.Text.tertiary) }
                        }
                    }
                }
            }
        } else {
            ContentUnavailableView("This fast round's file is gone", systemImage: "bolt.slash")
        }
    }
}

/// Selectable text with inline Markdown (bold, code, links) and the line breaks kept.
struct FastRoundText: View {
    private let text: AttributedString
    private let font: Font

    init(_ source: String, font: Font = TypographyTokens.standard) {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        text = (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
        self.font = font
    }

    var body: some View {
        Text(text).font(font).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Accept or reject the agent's analysis, with a note. Accept sends it to the agent to build into
/// Echo; Reject sends it back with the note so the agent revises its analysis.
struct FastRoundDecisionCard: View {
    let page: LabPage
    @Environment(LabStore.self) private var store
    @State private var note = ""
    private var draftKey: String { "draft.fast." + page.id }
    private var trimmed: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            LabColumnTitle(text: "Your verdict", symbol: "checkmark.seal")
            TextEditor(text: $note)
                .font(TypographyTokens.standard).frame(height: 90).scrollContentBackground(.hidden)
                .padding(6).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if note.isEmpty {
                        Text("Notes (optional on Accept, needed on Reject)")
                            .font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.tertiary).padding(11).allowsHitTesting(false)
                    }
                }
            HStack(spacing: SpacingTokens.xs) {
                Button { accept() } label: { Label("Accept", systemImage: "checkmark") }
                    .buttonStyle(LabPillButtonStyle(tint: ColorTokens.Status.success, prominent: true))
                Button { reject() } label: { Label("Reject", systemImage: "arrow.uturn.backward") }
                    .buttonStyle(LabPillButtonStyle(tint: ColorTokens.Status.error))
                    .disabled(trimmed.isEmpty)
                Text("Accept hands it to the agent to build. Reject sends your note back for a new analysis.")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .labCard(cornerRadius: 14)
        .onAppear { note = LabPrefs.load(draftKey, default: "") }
        .onChange(of: note) { _, new in LabPrefs.save(new, key: draftKey) }
    }

    private func accept() {
        if trimmed.isEmpty { store.accept(page) } else { store.acceptPicks(page, summary: "Accepted: " + trimmed) }
        note = ""
    }

    private func reject() {
        store.sendFeedback(page, comment: "Rejected: " + trimmed, event: "Rejected")
        note = ""
    }
}
