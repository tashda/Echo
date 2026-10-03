import SwiftUI
import HatchCore

/// History: every event on the ticket, newest first, searchable (decision F5).
struct TicketHistoryTab: View {
    let ticket: Ticket
    @EnvironmentObject var state: AppState

    @State private var events: [Event] = []
    @State private var search = ""
    @State private var tokens: (input: Int, output: Int) = (0, 0)

    private var filtered: [Event] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return events }
        return events.filter { e in
            EventText.describe(e).lowercased().contains(q) || e.actor.lowercased().contains(q) || e.kind.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search the history", text: $search)
                    .textFieldStyle(.plain)
                Spacer()
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            Divider()
            List(filtered) { event in
                HistoryRow(event: event)
            }
            .listStyle(.inset)
        }
        .autoReload(every: 5) { load() }
    }

    private var summary: String {
        let total = tokens.input + tokens.output
        let cost = total > 0 ? " · \(Format.tokens(total)) tokens" : ""
        return Format.count(events.count, "event") + cost
    }

    private func load() {
        let all: [Event] = (try? state.store.events(ticketId: ticket.id)) ?? []
        let reversed: [Event] = all.reversed()
        if reversed.map({ $0.id }) != events.map({ $0.id }) { events = reversed }
        tokens = (try? state.store.tokenTotals(ticketId: ticket.id)) ?? (input: 0, output: 0)
    }
}

struct HistoryRow: View {
    let event: Event

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: EventText.symbol(event))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(event.actor)
                .font(.callout.weight(.semibold))
                .frame(width: 70, alignment: .leading)
                .lineLimit(1)
            Text(EventText.describe(event))
                .font(.callout)
                .lineLimit(3)
            Spacer(minLength: 8)
            Text(Format.clock(event.at))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
