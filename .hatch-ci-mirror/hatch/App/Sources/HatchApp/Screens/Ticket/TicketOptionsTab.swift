import SwiftUI
import HatchCore

/// Options (Proposal) or Variants (Sketch). The Sketch is drawn by SketchBoard; the Proposal is judged in its own Stage window,
/// so this tab only summarises it and offers the Open Stage button (decisions F1, G, H, S5).
struct TicketOptionsTab: View {
    let ticket: Ticket
    let info: ProposalInfo
    @EnvironmentObject var state: AppState

    @State private var picks: [Pick] = []
    @State private var verdicts: [Verdict] = []
    @State private var pinCount = 0
    @State private var revisions: [Revision] = []

    var body: some View {
        switch ticket.type {
        case .sketch:
            SketchBoard(ticketId: ticket.id)
        case .proposal:
            proposalBody
                .autoReload(every: 5) { load() }
        default:
            ContentUnavailableView("No options for this type", systemImage: "square.stack.3d.up",
                                   description: Text("Only Sketches and Proposals have options."))
        }
    }

    private var proposalBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                openStageCard
                if info.hasManifest {
                    summaryCard
                    if !info.recommendations.isEmpty { recommendationCard }
                    if !picks.isEmpty || !verdicts.isEmpty { judgingCard }
                }
                if !revisions.isEmpty { revisionCard }
            }
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var canOpenStage: Bool {
        [.yourCall, .revising, .preparing, .accepted, .building, .toVerify, .fixing].contains(ticket.status) || info.hasManifest
    }

    private var openStageCard: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Revision \(ticket.revision)")
                    .font(.headline)
                Text(stageLine)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                StageLauncher.shared.open(ticket: ticket, state: state)
            } label: {
                Label("Open Stage", systemImage: "rectangle.on.rectangle")
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(Theme.color(for: ticket.turn))
            .disabled(!canOpenStage)
        }
        .padding(16)
        .background(Theme.background(for: ticket.turn), in: RoundedRectangle(cornerRadius: 10))
    }

    private var stageLine: String {
        if !info.hasManifest { return "No options yet. An agent is still preparing them." }
        let options = Format.count(info.optionCount, "option")
        let scenarios = Format.count(info.scenarioCount, "scenario")
        return "\(options), \(scenarios). The Stage opens in its own window, so Hatch never has to be rebuilt."
    }

    private var summaryCard: some View {
        SectionCard("What the agent offers") {
            if !info.summary.isEmpty {
                Text(info.summary).fixedSize(horizontal: false, vertical: true)
            }
            if let asked = info.manifest?.asked, !asked.isEmpty {
                Text("Asked: \(asked)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if !info.specs.isEmpty {
                Text("Changes " + info.specs.joined(separator: ", "))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var recommendationCard: some View {
        SectionCard("Hatch recommends") {
            ForEach(info.recommendations) { rec in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(rec.topicTitle): \(rec.choiceName)")
                        .font(.callout.weight(.semibold))
                    if let why = rec.why, !why.isEmpty {
                        Text(why)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var judgingCard: some View {
        SectionCard("Your picks so far") {
            ForEach(picks, id: \.topic) { pick in
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.finished)
                    Text("\(pick.topic): \(pick.choice)")
                        .font(.callout)
                }
            }
            if !verdicts.isEmpty {
                Text(verdictLine)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if pinCount > 0 {
                Text(Format.count(pinCount, "pinned note"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var verdictLine: String {
        let p = verdicts.filter { $0.verdict == "pick" }.count
        let m = verdicts.filter { $0.verdict == "maybe" }.count
        let n = verdicts.filter { $0.verdict == "no" }.count
        return "Verdicts: \(p) Pick, \(m) Maybe, \(n) No"
    }

    private var revisionCard: some View {
        SectionCard("Revisions") {
            ForEach(revisions, id: \.n) { rev in
                VStack(alignment: .leading, spacing: 2) {
                    Text("Revision \(rev.n) · \(Format.ago(rev.at))")
                        .font(.callout.weight(.semibold))
                    Text(rev.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !rev.added.isEmpty {
                        Text("Added: " + rev.added.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func load() {
        let id = ticket.id
        picks = (try? state.store.picks(ticketId: id)) ?? []
        verdicts = (try? state.store.verdicts(ticketId: id)) ?? []
        pinCount = ((try? state.store.pins(ticketId: id)) ?? []).count
        revisions = (try? state.store.revisions(ticketId: id)) ?? []
    }
}
