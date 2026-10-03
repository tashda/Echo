import SwiftUI
import HatchCore

/// One card per open question, with suggested answers as buttons and a free text field (decision E4).
/// Answering the last open question moves the ticket to Ready; the store does that, not this view.
struct AnswerCardsView: View {
    @EnvironmentObject var state: AppState
    let ticketId: Int
    @State private var questions: [Question] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(questions) { question in
                AnswerCard(question: question)
            }
        }
        .autoReload(every: 4) { load() }
    }

    private func load() {
        let open: [Question] = (try? state.store.questions(ticketId: ticketId, openOnly: true)) ?? []
        if open != questions { questions = open }
    }
}

struct AnswerCard: View {
    @EnvironmentObject var state: AppState
    let question: Question
    @State private var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.bubble")
                    .foregroundStyle(Theme.you)
                Text("\(question.askedBy) asks")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Format.ago(question.at))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Text(question.text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            if !question.suggestions.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(question.suggestions, id: \.self) { suggestion in
                        Button(suggestion) { text = suggestion }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("Your answer", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { send() }
                Button("Answer") { send() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.you)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(Theme.youBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.you.opacity(0.35)))
    }

    private func send() {
        let answer = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return }
        let id = question.id
        _ = state.perform("Could not save the answer") { try state.store.answer(questionId: id, text: answer) }
    }
}
