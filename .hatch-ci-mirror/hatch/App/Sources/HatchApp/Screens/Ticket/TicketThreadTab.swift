import SwiftUI
import HatchCore

/// One entry in the merged timeline of notes, questions, answers and events (decision F3).
struct ThreadItem: Identifiable {
    enum Content {
        case note(Note)
        case question(Question)
        case answer(Question)
        case event(Event)
    }
    let id: String
    let at: Date
    let content: Content
}

/// Thread: one timeline with filter toggles, and a composer with three message kinds (decisions F3, F4).
struct TicketThreadTab: View {
    let ticket: Ticket
    /// The message kind to start with, so "Send instruction" on the Work tab lands on Instruction (decision I5).
    var startKind: NoteKind = .note
    @EnvironmentObject var state: AppState

    @State private var items: [ThreadItem] = []
    @State private var showMessages = true
    @State private var showQuestions = true
    @State private var showEvents = false
    @State private var kind: NoteKind = .note
    @State private var draft = ""

    private var visible: [ThreadItem] {
        items.filter { item in
            switch item.content {
            case .note: return showMessages
            case .question, .answer: return showQuestions
            case .event: return showEvents
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterRow
            Divider()
            timeline
            Divider()
            composer
        }
        .autoReload(every: 4) { load() }
        .onAppear { kind = startKind }
    }

    private var filterRow: some View {
        HStack(spacing: 16) {
            Toggle("Messages", isOn: $showMessages)
            Toggle("Questions", isOn: $showQuestions)
            Toggle("Events", isOn: $showEvents)
            Spacer()
            Text(Format.count(visible.count, "entry").replacingOccurrences(of: "entrys", with: "entries"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .toggleStyle(.checkbox)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if visible.isEmpty {
                        Text("Nothing here yet. Add a note, ask a question or give an instruction below.")
                            .foregroundStyle(.secondary)
                            .padding(.top, 20)
                    }
                    ForEach(visible) { item in
                        ThreadRow(item: item)
                            .id(item.id)
                    }
                    Color.clear.frame(height: 1).id("end")
                }
                .padding(20)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: visible.count) { _, _ in
                proxy.scrollTo("end", anchor: .bottom)
            }
            .onAppear { proxy.scrollTo("end", anchor: .bottom) }
        }
    }

    // MARK: Composer

    private static let kinds: [NoteKind] = [.note, .ask, .instruction]

    private func kindTitle(_ k: NoteKind) -> String {
        switch k {
        case .ask: return "Ask"
        case .instruction: return "Instruction"
        default: return "Note"
        }
    }

    private var kindHelp: String {
        switch kind {
        case .ask: return "Ask expects an answer and moves the turn to the agent."
        case .instruction: return "Instruction changes the work. On a Proposal it sends it back for a new revision."
        default: return "Note adds context. Nobody has to act on it."
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Picker("Kind", selection: $kind) {
                    ForEach(Self.kinds, id: \.self) { k in
                        Text(kindTitle(k)).tag(k)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)
                Text(kindHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextEditor(text: $draft)
                    .font(.body)
                    .frame(height: 70)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                Button { send() } label: { Label("Send \(kindTitle(kind))", systemImage: "paperplane") }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func send() {
        let text = draft
        let id = ticket.id
        let chosen = kind
        let ok: Note? = state.perform("Could not send the message") { try state.store.addNote(id, kind: chosen, author: "owner", body: text) }
        if ok != nil { draft = "" }
    }

    // MARK: Data

    private func load() {
        let store = state.store
        let id = ticket.id
        var out: [ThreadItem] = []
        for note in (try? store.notes(ticketId: id)) ?? [] {
            out.append(ThreadItem(id: "n\(note.id)", at: note.at, content: .note(note)))
        }
        for q in (try? store.questions(ticketId: id)) ?? [] {
            out.append(ThreadItem(id: "q\(q.id)", at: q.at, content: .question(q)))
            if q.answer != nil, let answeredAt = q.answeredAt {
                out.append(ThreadItem(id: "a\(q.id)", at: answeredAt, content: .answer(q)))
            }
        }
        let skip: Set<String> = ["note", "question", "answer"]
        for e in (try? store.events(ticketId: id)) ?? [] where !skip.contains(e.kind) {
            out.append(ThreadItem(id: "e\(e.id)", at: e.at, content: .event(e)))
        }
        out.sort { $0.at < $1.at }
        if out.map({ $0.id }) != items.map({ $0.id }) { items = out }
    }
}

struct ThreadRow: View {
    let item: ThreadItem

    var body: some View {
        switch item.content {
        case .note(let note): NoteBubble(note: note)
        case .question(let q): QuestionBubble(question: q)
        case .answer(let q): AnswerBubble(question: q)
        case .event(let e): EventLine(event: e)
        }
    }
}

struct NoteBubble: View {
    let note: Note

    private var fromOwner: Bool { note.author == "owner" }

    private var kindLabel: String {
        switch note.kind {
        case .ask: return "Ask"
        case .instruction: return "Instruction"
        case .agent: return "Agent"
        case .system: return "System"
        case .comment: return "Comment"
        case .note: return "Note"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(fromOwner ? "You" : note.author)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(fromOwner ? Theme.you : Theme.agent)
                PlainChip(text: kindLabel)
                Spacer()
                Text(Format.ago(note.at))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Text(note.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((fromOwner ? Theme.youBackground : Theme.agentBackground).opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct QuestionBubble: View {
    let question: Question

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.bubble").foregroundStyle(Theme.agent)
                Text("\(question.askedBy) asks")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Theme.agent)
                if question.isOpen { PlainChip(text: "Open") }
                Spacer()
                Text(Format.ago(question.at))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Text(question.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.agentBackground.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct AnswerBubble: View {
    let question: Question

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("You answered")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Theme.you)
                Spacer()
                if let at = question.answeredAt {
                    Text(Format.ago(at))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Text(question.answer ?? "")
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.youBackground.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct EventLine: View {
    let event: Event

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: EventText.symbol(event))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(event.actor)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(EventText.describe(event))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Text(Format.ago(event.at))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 4)
    }
}
