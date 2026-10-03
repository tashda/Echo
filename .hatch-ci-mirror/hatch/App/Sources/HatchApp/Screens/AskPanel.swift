import SwiftUI
import HatchCore

/// Ask Hatch (decision B4): a right-side panel that keeps the current ticket as context.
/// The exchange is also saved to the ticket thread. Claude runs in a background Task, never on the main thread.
struct AskPanel: View {
    @EnvironmentObject var state: AppState

    struct Message: Identifiable {
        let id = UUID()
        let fromOwner: Bool
        let text: String
    }

    @State private var input = ""
    @State private var messages: [Message] = []
    @State private var running = false
    @State private var errorText: String?
    @State private var messagesTicketId: Int?

    private var currentTicket: Ticket? {
        guard let id = state.selectedTicketId else { return nil }
        if case .ticket = state.route {
            let t: Ticket? = try? state.store.ticket(id: id)
            return t
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            conversation
            Divider()
            composer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: currentTicket?.id) { _, newValue in
            if newValue != messagesTicketId {
                messages = []
                errorText = nil
                messagesTicketId = newValue
            }
        }
    }

    // MARK: Parts

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
            VStack(alignment: .leading, spacing: 1) {
                Text("Ask Hatch").font(.headline)
                if let t = currentTicket {
                    Text("About \(t.displayNumber) \(t.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                } else {
                    Text("No ticket open. Answers are not saved.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { state.showAskPanel = false } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .help("Close (\u{2325}\u{2318}A)")
        }
        .padding(10)
    }

    private var conversation: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if messages.isEmpty && !running && errorText == nil {
                    Text("Ask about this ticket, its options, or what to do next.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(messages) { m in bubble(m) }
                if running {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Claude is thinking...").font(.callout).foregroundStyle(.secondary)
                    }
                }
                if let e = errorText { errorView(e) }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func bubble(_ m: Message) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(m.fromOwner ? "You" : "Claude").font(.caption).foregroundStyle(.secondary)
            Text(m.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func errorView(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HXChip(text: "Could not answer", turn: .you)
            Text(text).font(.callout).textSelection(.enabled)
        }
    }

    private var composer: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TextField("Ask a question", text: $input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...6)
                .onSubmit { send() }
            Button { send() } label: { Label(running ? "Waiting..." : "Send", systemImage: "paperplane") }
                .buttonStyle(.glassProminent)
                .disabled(running || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(10)
    }

    // MARK: Sending

    private func contextText(_ t: Ticket) -> String {
        var lines: [String] = []
        lines.append("Ticket \(t.displayNumber): \(t.title)")
        lines.append("Type: \(t.type.displayName). Status: \(t.status.displayName).")
        if !t.body.isEmpty { lines.append("Description:\n" + String(t.body.prefix(3000))) }
        let questions = (try? state.store.questions(ticketId: t.id, openOnly: true)) ?? []
        if !questions.isEmpty {
            lines.append("Open questions:\n" + questions.map { "- " + $0.text }.joined(separator: "\n"))
        }
        let notes = (try? state.store.notes(ticketId: t.id)) ?? []
        let recent = notes.suffix(6)
        if !recent.isEmpty {
            lines.append("Recent thread:\n" + recent.map { "\($0.author): \(String($0.body.prefix(400)))" }.joined(separator: "\n"))
        }
        return lines.joined(separator: "\n\n")
    }

    private func send() {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !running else { return }
        let ticket = currentTicket
        var prompt = "You are helping the owner of a software project use Hatch, a ticket and design-decision tool. Answer briefly and plainly.\n\n"
        if let ticket { prompt += "Context:\n" + contextText(ticket) + "\n\n" }
        prompt += "Question: " + question
        let configured = state.hxSetting("claude_path")
        messages.append(Message(fromOwner: true, text: question))
        messagesTicketId = ticket?.id
        input = ""
        errorText = nil
        running = true
        Task {
            let path = await Task.detached { HXAskAdapter.locateClaude(setting: configured) }.value
            guard let path else {
                errorText = "claude CLI not found. Install Claude Code, or set its path in Settings."
                running = false
                return
            }
            do {
                let answer = try await HXAskAdapter.ask(prompt: prompt, claudePath: path)
                messages.append(Message(fromOwner: false, text: answer.text))
                save(ticket: ticket, question: question, answer: answer.text)
                recordCost(ticket: ticket, answer: answer)
            } catch {
                errorText = "\(error)"
            }
            running = false
        }
    }

    private func save(ticket: Ticket?, question: String, answer: String) {
        guard let ticket else { return }
        state.perform("Save to thread") {
            try state.store.addNote(ticket.id, kind: .note, author: "owner", body: "Asked Claude: " + question)
            try state.store.addNote(ticket.id, kind: .agent, author: "Claude", body: answer)
        }
    }

    private func recordCost(ticket: Ticket?, answer: HXAskAdapter.Answer) {
        state.perform("Record cost") {
            let runId = try state.store.startRun(ticketId: ticket?.id, agent: "ask", step: "ask")
            try state.store.endRun(runId, tokensIn: answer.tokensIn, tokensOut: answer.tokensOut, outcome: "ok")
        }
    }
}
