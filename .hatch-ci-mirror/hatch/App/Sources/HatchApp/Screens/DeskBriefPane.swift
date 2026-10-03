import SwiftUI
import HatchCore

/// The short brief on the right of the Desk: what is asked, how big it is, what Hatch recommends (decisions C1, C3).
struct DeskBriefPane: View {
    @EnvironmentObject var state: AppState
    let ticket: Ticket
    let info: ProposalInfo
    let questions: [Question]
    let notice: String?
    let onOpen: () -> Void
    let onPark: () -> Void
    let onAsk: () -> Void
    let onAccept: () -> Void

    private var copy: DeskCopy {
        DeskCopy.make(ticket: ticket, info: info, openQuestions: questions.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                crumbs
                Text("\(ticket.displayNumber)  \(ticket.title)")
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                turnLine
                facts
                recommendation
                questionList
                excerpt
                actions
                if let notice {
                    Text(notice)
                        .font(.callout)
                        .foregroundStyle(Theme.critical)
                        .fixedSize(horizontal: false, vertical: true)
                }
                hint
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var crumbs: some View {
        HStack(spacing: 6) {
            StatusChip(status: ticket.status)
            Text(crumbText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var crumbText: String {
        var parts: [String] = [ticket.type.displayName]
        if let area = ticket.area, !area.isEmpty { parts.append(area) }
        if let name = state.project(id: ticket.projectId)?.name { parts.append(name) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var turnLine: some View {
        if ticket.turn == .you {
            Text("Your turn: \(copy.action.lowercased()).")
                .font(.body)
                .foregroundStyle(Theme.you)
        } else {
            Text("\(Theme.turnTitle(ticket.turn)). Nothing for you to do yet.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var facts: some View {
        if ticket.type == .proposal && info.hasManifest {
            VStack(alignment: .leading, spacing: 4) {
                Text(factsLine)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if !info.summary.isEmpty {
                    Text(info.summary)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var factsLine: String {
        var parts: [String] = ["Revision \(ticket.revision)"]
        if info.scenarioCount > 0 { parts.append(Format.count(info.scenarioCount, "scenario")) }
        if !info.specs.isEmpty { parts.append("changes " + info.specs.joined(separator: ", ")) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var recommendation: some View {
        if ticket.status == .yourCall, !info.recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(info.recommendations) { rec in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hatch recommends \(rec.choiceName)")
                            .font(.callout.weight(.semibold))
                        Text(rec.topicTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let why = rec.why, !why.isEmpty {
                            Text(why)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.youBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder private var questionList: some View {
        if !questions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(questions) { question in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(question.text)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                        if let first = question.suggestions.first {
                            Text("Suggested: \(first)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var excerpt: some View {
        if !ticket.body.isEmpty && questions.isEmpty && info.summary.isEmpty {
            Text(String(ticket.body.prefix(420)))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button(action: onOpen) {
                Label("Open", systemImage: "return")
            }
            .buttonStyle(.glassProminent)
            Button(action: onPark) {
                Label("Park", systemImage: "pause")
            }
            .buttonStyle(.glass)
            .help("Park (P)")
            Button(action: onAsk) {
                Label("Ask", systemImage: "sparkles")
            }
            .buttonStyle(.glass)
            .help("Ask (\u{2325}\u{2318}A)")
            if canAccept {
                Button(action: onAccept) {
                    Label("Accept recommendation", systemImage: "checkmark")
                }
                .buttonStyle(.glass)
                .help("Accept (A)")
            }
        }
        .controlSize(.large)
    }

    private var canAccept: Bool {
        if ticket.status == .yourCall && ticket.type == .proposal { return !info.recommendations.isEmpty }
        return ticket.status == .needsAnswers && !questions.isEmpty
    }

    private var hint: some View {
        Text("Move with J and K. A accepts Hatch's recommendation from the list; a sheet asks you to confirm first.")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
