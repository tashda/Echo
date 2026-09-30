import EchoSenseScenarios
import SwiftUI

/// The feedback thread under a scenario: your messages and the agent's answers, oldest first, and a
/// box to write the next one (about the whole scenario or one check). An agent finds messages that
/// wait for it with lab-inbox.py and answers with `echosense-scenarios comment`.
struct ScenarioThreadCard: View {
    let comments: [ScenarioComment]
    /// The checks, to name the one a message is about.
    let checks: [ScenarioCheck]
    @Binding var draft: String
    /// The check the next message is about; nil for the whole scenario.
    @Binding var about: String?
    var focus: FocusState<Bool>.Binding
    let send: () -> Void
    let delete: (String) -> Void

    private static let reasons = ["The order is wrong", "Should offer more", "Should offer less", "Nothing should appear here",
                                  "Inserts the wrong text", "Wrong setting (dialect, schema or trigger)", "Should follow a rule"]

    var body: some View {
        LabReadingCard(title: "Feedback for the agent", symbol: "bubble.left.and.bubble.right") {
            if comments.isEmpty {
                Text("Write what should change. The agent reads it next time it works through your reviews.")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
            ForEach(comments) { comment in message(comment) }
            composer
        }
    }

    private func message(_ comment: ScenarioComment) -> some View {
        let isOwner = comment.author == .owner
        return VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            HStack(spacing: SpacingTokens.xxs) {
                Image(systemName: isOwner ? "person.fill" : "sparkles").foregroundStyle(isOwner ? ColorTokens.accent : ColorTokens.Status.success)
                Text(isOwner ? "You" : "Agent").font(TypographyTokens.detail.weight(.semibold))
                Text(Self.date(comment.date)).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                if let about = comment.about { LabTag(text: aboutTitle(about), symbol: "scope") }
                Spacer()
                if isOwner, comment.id == comments.last?.id {
                    Button("Delete", systemImage: "trash") { delete(comment.id) }.labelStyle(.iconOnly).buttonStyle(.borderless)
                        .help("Take back your last message")
                }
            }
            Text(ScenarioChecksCard.markdown(comment.text)).font(TypographyTokens.standard).textSelection(.enabled)
        }
        .padding(SpacingTokens.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isOwner ? ColorTokens.Surface.selected : ColorTokens.Surface.rest, in: .rect(cornerRadius: 8))
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            if let about {
                HStack(spacing: SpacingTokens.xxs) {
                    Text("About:").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    ScenarioChip(text: aboutTitle(about), mono: false) { self.about = nil }
                }
            }
            HStack(alignment: .bottom, spacing: SpacingTokens.xs) {
                TextField("", text: $draft, prompt: Text("What should change? Return sends"), axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(1...6).focused(focus)
                    .onSubmit(send)
                Button("Send", systemImage: "paperplane", action: send)
                    .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, prominent: !draft.isEmpty))
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            LabFlowLayout {
                ForEach(Self.reasons, id: \.self) { reason in
                    Button(reason) { draft = draft.isEmpty ? reason : "\(draft). \(reason)"; focus.wrappedValue = true }
                        .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, isOn: draft.contains(reason)))
                }
            }
        }
    }

    private func aboutTitle(_ id: String) -> String {
        checks.first { $0.id == id }.map { $0.statement.replacingOccurrences(of: "`", with: "") } ?? id
    }

    private static func date(_ iso: String) -> String {
        (try? Date(iso, strategy: .iso8601)).map { $0.formatted(date: .abbreviated, time: .shortened) } ?? iso
    }
}
