import SwiftUI
import HatchCore
import HatchAgent

/// One recommended answer from a Proposal's manifest ("Hatch recommends B").
struct ProposalRecommendation: Identifiable {
    let id: String            // topic id
    let topicTitle: String
    let choiceId: String
    let choiceName: String
    let why: String?
}

/// A short, read-only view of a Proposal's manifest for the Desk brief and the ticket's Options tab.
struct ProposalInfo {
    var manifest: ProposalManifest?
    var recommendations: [ProposalRecommendation] = []
    var optionCount: Int = 0
    var revision: Int = 1
    var summary: String = ""
    var specs: [String] = []
    var scenarioCount: Int = 0

    var hasManifest: Bool { manifest != nil }

    static func load(store: HatchStore, ticket: Ticket) -> ProposalInfo {
        var info = ProposalInfo()
        info.revision = ticket.revision
        guard ticket.type == .proposal else { return info }
        guard let json = try? store.proposalManifest(ticketId: ticket.id) else { return info }
        guard let manifest = try? ProposalManifest.parse(json: json) else { return info }
        info.manifest = manifest
        info.optionCount = manifest.proposalSpecimens.count
        info.summary = manifest.summary
        info.specs = manifest.specs
        info.scenarioCount = manifest.scenarios.count
        var list: [ProposalRecommendation] = []
        for control in manifest.controls {
            guard let rec = control.recommend, !rec.isEmpty else { continue }
            let name: String = control.choices.first(where: { $0.id == rec })?.name ?? rec
            list.append(ProposalRecommendation(id: control.id, topicTitle: control.title, choiceId: rec, choiceName: name, why: control.why))
        }
        for question in manifest.questions {
            guard let rec = question.recommended, !rec.isEmpty else { continue }
            let name: String = question.choices.first(where: { $0.id == rec })?.name ?? rec
            list.append(ProposalRecommendation(id: question.id, topicTitle: question.title, choiceId: rec, choiceName: name, why: question.why))
        }
        info.recommendations = list
        return info
    }
}

/// What to do about a ticket and roughly how long it takes, in the plain words of the Desk (decision C3).
struct DeskCopy {
    let action: String
    let minutes: Int

    var line: String { minutes > 0 ? "\(action) · about \(minutes) min" : action }

    static func make(ticket: Ticket, info: ProposalInfo, openQuestions: Int) -> DeskCopy {
        switch ticket.status {
        case .yourCall:
            switch ticket.type {
            case .proposal:
                let n = max(info.optionCount, 1)
                return DeskCopy(action: "Judge \(Format.count(n, "option"))", minutes: max(2, n * 2))
            case .sketch:
                return DeskCopy(action: "Choose a direction", minutes: 3)
            default:
                return DeskCopy(action: "Reply needed", minutes: 2)
            }
        case .needsAnswers:
            let n = max(openQuestions, 1)
            return DeskCopy(action: "Iris asks \(Format.count(n, "question"))", minutes: max(1, n))
        case .toVerify:
            return DeskCopy(action: "Verify in Previews", minutes: 3)
        case .draft:
            return DeskCopy(action: "Finish and submit", minutes: 2)
        default:
            return DeskCopy(action: ticket.status.displayName, minutes: 0)
        }
    }
}
