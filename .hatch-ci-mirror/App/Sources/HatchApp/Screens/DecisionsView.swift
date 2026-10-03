import SwiftUI
import HatchCore

/// Decisions: frozen results, read only, each linked to its ticket (decision N1).
struct DecisionsView: View {
    @EnvironmentObject var state: AppState
    @State private var filter = ""

    private var rows: [(ticket: Ticket, summary: String, specCodes: [String], at: Date)] {
        let all = (try? state.store.decisions(projectId: state.projectFilterId)) ?? []
        let f = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if f.isEmpty { return all }
        return all.filter { d in
            d.summary.lowercased().contains(f) || d.ticket.title.lowercased().contains(f) || d.specCodes.contains { $0.lowercased().contains(f) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HXHeader(title: "Decisions", subtitle: "What was decided and why. Read only.")
                Spacer()
                TextField("Filter", text: $filter).textFieldStyle(.roundedBorder).frame(width: 220)
            }
            .padding(12)
            Divider()
            let list = rows
            if list.isEmpty {
                HXEmpty(symbol: "flag", title: "No decisions yet", detail: "A decision is recorded when you accept a Proposal.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(list.enumerated()), id: \.offset) { _, d in card(d.ticket, d.summary, d.specCodes, d.at) }
                    }
                    .padding(16)
                    .frame(maxWidth: 820, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func card(_ ticket: Ticket, _ summary: String, _ codes: [String], _ at: Date) -> some View {
        HXCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Button { state.open(ticket) } label: { Text("\(ticket.displayNumber) \(ticket.title)").lineLimit(1) }
                        .buttonStyle(.link)
                    Spacer()
                    Text(at.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                }
                Text(summary).textSelection(.enabled)
                if !codes.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(codes, id: \.self) { code in
                            Text(code).font(.caption.monospaced()).padding(.horizontal, 6).padding(.vertical, 1)
                                .background(Theme.hatchBackground, in: Capsule())
                        }
                    }
                }
            }
        }
    }
}
