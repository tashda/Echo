import AppKit
import SwiftUI

/// Handing a round to any agent: the prompt the owner pastes into a new agent session. The prompt
/// runs `EchoLab/Scripts/lab-brief.py`, which prints everything the agent needs (what was asked, the
/// owner's answers, the code, the steps for the round's status) and records that it took the round.
@MainActor
enum LabAgentHandoff {
    /// The Echo checkout, found from where the state file lives (`<repo>/EchoLab/State/lab-state.json`).
    static var repositoryPath: String {
        LabStore.defaultFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
    }

    static func prompt(for page: LabPage, status: LabStatus?) -> String {
        let tag = LabRoundName.tag(forPage: page.id, title: page.title).map { "\($0) · " } ?? ""
        let name = LabRoundName.split(page.title).name
        let what: String = switch status {
        case .accepted: "The owner accepted it: build it into Echo."
        case .newFeedback: "The owner sent feedback on it: revise the round."
        case .decided: "The owner confirmed it in Echo: freeze it into the library."
        case .inEcho: "It is built into Echo and waiting for the owner's check."
        case .judging, nil: "The owner is still judging it."
        }
        return """
        Take Echo Labs round \(tag)\(name) (\(page.id)). \(what)
        In \(repositoryPath), read AGENTS.md, then run:
        python3 EchoLab/Scripts/lab-brief.py \(page.id) --take "<a short name for you>"
        and do what the brief says. Other agents work in the same checkout: commit only your own paths.
        """
    }
}

/// "Copy for an agent": puts the handoff prompt on the pasteboard.
struct LabAgentHandoffButton: View {
    let page: LabPage
    var iconOnly = false
    @Environment(LabStore.self) private var store
    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(LabAgentHandoff.prompt(for: page, status: store.status(of: page)), forType: .string)
            copied = true
            Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
        } label: {
            Label(copied ? "Copied" : "Copy for an agent", systemImage: copied ? "checkmark" : "person.crop.circle.badge.plus")
        }
        .labelStyle(LabOptionalIconOnlyLabelStyle(iconOnly: iconOnly))
        .help("Copies a prompt that hands this round to any agent: it runs lab-brief.py, which tells the agent what to do")
    }
}

/// "Taken by …" when an agent is working on the round in its current status.
struct LabClaimTag: View {
    let page: LabPage
    @Environment(LabStore.self) private var store

    var body: some View {
        if let claim = store.claim(of: page) {
            LabTag(text: "Taken by \(claim.agent)", symbol: "person.fill")
                .help("Taken \(claim.date.formatted(date: .abbreviated, time: .shortened)) with lab-brief.py --take")
        }
    }
}

private struct LabOptionalIconOnlyLabelStyle: LabelStyle {
    let iconOnly: Bool
    func makeBody(configuration: Configuration) -> some View {
        if iconOnly { configuration.icon } else { Label(configuration) }
    }
}
