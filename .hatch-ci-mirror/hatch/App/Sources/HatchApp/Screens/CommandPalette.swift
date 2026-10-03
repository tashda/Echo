import SwiftUI
import HatchCore

/// Cmd-K: search tickets (full-text), Spec items and commands. Return opens the first hit.
struct CommandPalette: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var selection = 0
    @FocusState private var focused: Bool

    struct Hit: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let symbol: String
        let run: () -> Void
    }

    // MARK: Hits

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func commands() -> [Hit] {
        let list: [(String, String, Route)] = [
            ("Go to Desk", "tray", .desk), ("Go to Tickets", "list.bullet", .tickets), ("Go to Board", "rectangle.split.3x1", .board),
            ("Go to Previews", "eye", .previews), ("Go to Specs", "doc.text", .specs), ("Go to Decisions", "flag", .decisions),
            ("Go to Agents", "cpu", .agents), ("Go to Log", "list.bullet.rectangle", .log), ("Go to Project", "gearshape", .projects),
        ]
        var hits: [Hit] = [
            Hit(id: "cmd-new", title: "New ticket", subtitle: "Command", symbol: "plus", run: { state.route = .newTicket }),
            Hit(id: "cmd-ask", title: "Ask Hatch", subtitle: "Command", symbol: "sparkles", run: { state.showAskPanel.toggle() }),
        ]
        for entry in list {
            let route = entry.2
            hits.append(Hit(id: "cmd-" + entry.0, title: entry.0, subtitle: "Command", symbol: entry.1, run: { state.route = route }))
        }
        return hits
    }

    private var hits: [Hit] {
        let q = trimmed
        if q.isEmpty { return commands() }
        var out: [Hit] = []

        if let t = try? state.store.resolve(q) {
            out.append(ticketHit(t))
        }
        let found = (try? state.store.tickets(TicketFilter(projectId: state.projectFilterId, text: q, limit: 8))) ?? []
        for t in found where !out.contains(where: { $0.id == "t\(t.id)" }) { out.append(ticketHit(t)) }

        if let pid = state.hxProject?.id {
            let specs = (try? state.store.searchSpec(projectId: pid, query: q, limit: 5)) ?? []
            for s in specs {
                out.append(Hit(id: "s\(s.id)", title: "\(s.code)  \(s.text)", subtitle: "Spec" + (s.area.map { " · \($0)" } ?? ""), symbol: "doc.text",
                               run: { state.route = .specs }))
            }
        }
        let lower = q.lowercased()
        out += commands().filter { $0.title.lowercased().contains(lower) }
        out.append(Hit(id: "cmd-capture", title: "Capture \u{201C}\(q)\u{201D} as a draft", subtitle: "Quick capture · only a title",
                       symbol: "plus.circle", run: { captureDraft(title: q) }))
        return out
    }

    private func ticketHit(_ t: Ticket) -> Hit {
        Hit(id: "t\(t.id)", title: "\(t.displayNumber)  \(t.title)", subtitle: "\(t.type.displayName) · \(t.status.displayName)",
            symbol: Theme.symbol(for: t.type), run: { state.open(t) })
    }

    /// Quick capture (decision E1): a Draft with only a title, no check, in the current or first project.
    /// The type is Question, the lightest one; it can be changed on the ticket.
    private func captureDraft(title: String) {
        guard let pid = state.projectFilterId ?? state.projects.first?.id else {
            state.errorMessage = "Add a project before capturing a ticket."
            return
        }
        let created: Ticket? = state.perform("Could not capture the draft") {
            try state.store.createTicket(projectId: pid, type: .question, title: title, body: "",
                                         area: nil, parentId: nil, status: .draft, actor: .owner)
        }
        if let created { state.open(created) }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search tickets, Spec items and commands", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding(14)
                .focused($focused)
                .onSubmit { activate(at: selection) }
                .onChange(of: query) { _, _ in selection = 0 }
                .onKeyPress(.downArrow) { move(1); return .handled }
                .onKeyPress(.upArrow) { move(-1); return .handled }
            Divider()
            results
        }
        .frame(width: 560, height: 420)
        .onAppear { focused = true }
        .onExitCommand { dismiss() }
    }

    private var results: some View {
        let list = hits
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if list.isEmpty {
                    Text("Nothing found").foregroundStyle(.secondary).padding(14)
                }
                ForEach(Array(list.enumerated()), id: \.element.id) { index, hit in
                    row(hit, selected: index == selection)
                        .contentShape(Rectangle())
                        .onTapGesture { activate(at: index) }
                }
            }
        }
    }

    private func row(_ hit: Hit, selected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: hit.symbol).frame(width: 20).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(hit.title).lineLimit(1)
                Text(hit.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(selected ? Color.accentColor.opacity(0.18) : Color.clear)
    }

    private func move(_ delta: Int) {
        let count = hits.count
        if count == 0 { return }
        selection = min(max(selection + delta, 0), count - 1)
    }

    private func activate(at index: Int) {
        let list = hits
        guard index >= 0, index < list.count else { return }
        let hit = list[index]
        dismiss()
        hit.run()
    }
}
