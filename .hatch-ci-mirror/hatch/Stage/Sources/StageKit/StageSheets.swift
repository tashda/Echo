import SwiftUI
import StageCore

/// The content of whichever sheet is open: Accept (H16), Send back (H17), Ask (H14) or keyboard help (H20).
struct StageSheets: View {
    @ObservedObject var model: StageModel

    var body: some View {
        switch model.state.sheet {
        case .accept:
            AcceptSheet(model: model)
        case .sendBack:
            SendBackSheet(model: model)
        case .ask:
            AskSheet(model: model)
        case .help:
            HelpSheet(model: model)
        case .none:
            EmptyView()
        }
    }
}

struct AcceptSheet: View {
    @ObservedObject var model: StageModel

    var body: some View {
        let summary = StageAcceptSummary.make(manifest: model.manifest, state: model.state)
        VStack(alignment: .leading, spacing: 12) {
            Text("Accept this Proposal?").font(.title3.weight(.semibold))
            Text("Accepting starts an agent run that costs tokens. Check what will change.")
                .font(.callout)
                .foregroundStyle(.secondary)
            GroupBox("Your choices") {
                VStack(alignment: .leading, spacing: 4) {
                    if summary.lines.isEmpty {
                        Text("You have not answered any question.").font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(summary.lines, id: \.topicID) { line in
                        HStack(spacing: 6) {
                            Text(line.title).font(.callout)
                            Spacer()
                            Text(line.choice).font(.callout.weight(.semibold))
                            if line.isRecommended { Text("★").foregroundStyle(Color.orange) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }
            if !summary.undecided.isEmpty {
                Label("Not answered: \(summary.undecided.joined(separator: ", ")). The agent will use Hatch's recommendation.", systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(Color.orange)
            }
            GroupBox("Repos and branches that change") {
                VStack(alignment: .leading, spacing: 4) {
                    if summary.repos.isEmpty {
                        Text("None listed by the Proposal.").font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(summary.repos, id: \.name) { repo in
                        Text("\(repo.name) → \(repo.branch)").font(.callout.monospaced())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }
            GroupBox("Tests that run") {
                VStack(alignment: .leading, spacing: 4) {
                    if summary.tests.isEmpty {
                        Text("None listed by the Proposal.").font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(summary.tests, id: \.self) { test in
                        Text(test).font(.callout)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }
            Text("Estimated cost: \(StageAcceptSummary.formatTokens(summary.tokenEstimate))").font(.callout)
            HStack {
                Spacer()
                Button {
                    model.send(.dismissSheet)
                } label: {
                    Text("Cancel")
                }
                .buttonStyle(.glass)
                .keyboardShortcut(.cancelAction)
                Button {
                    model.send(.confirmAccept)
                } label: {
                    Text("Accept")
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}

struct SendBackSheet: View {
    @ObservedObject var model: StageModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Send back").font(.title3.weight(.semibold))
            Text("Say what kind of change you want, then what to change.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Picker("Reason", selection: model.binding({ $0.sendBackReason }, { StageAction.setSendBackReason($0) })) {
                ForEach(StageSendBackReason.allCases, id: \.self) { r in
                    Text(r.title).tag(r)
                }
            }
            .pickerStyle(.radioGroup)
            Text(model.state.sendBackReason.detail).font(.caption).foregroundStyle(.secondary)
            TextField(
                "What should change? (required)",
                text: model.binding({ $0.sendBackNote }, { StageAction.setSendBackNote($0) }),
                axis: .vertical
            )
            .lineLimit(4...8)
            .textFieldStyle(.roundedBorder)
            if let error = model.state.formError {
                Text(error).font(.callout).foregroundStyle(Color.red)
            }
            HStack {
                Spacer()
                Button {
                    model.send(.dismissSheet)
                } label: {
                    Text("Cancel")
                }
                .buttonStyle(.glass)
                .keyboardShortcut(.cancelAction)
                Button {
                    model.send(.confirmSendBack)
                } label: {
                    Text("Send back")
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

struct AskSheet: View {
    @ObservedObject var model: StageModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ask Hatch").font(.title3.weight(.semibold))
            Text("Your question is sent with the state you are looking at, so the agent sees what you see.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField(
                "What do you want to know before deciding?",
                text: model.binding({ $0.askDraft }, { StageAction.setAskDraft($0) }),
                axis: .vertical
            )
            .lineLimit(3...8)
            .textFieldStyle(.roundedBorder)
            Text(StageReducer.describe(model.state, manifest: model.manifest))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let error = model.state.formError {
                Text(error).font(.callout).foregroundStyle(Color.red)
            }
            HStack {
                Spacer()
                Button {
                    model.send(.dismissSheet)
                } label: {
                    Text("Cancel")
                }
                .buttonStyle(.glass)
                .keyboardShortcut(.cancelAction)
                Button {
                    model.send(.sendAsk)
                } label: {
                    Text("Send question")
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}

struct HelpSheet: View {
    @ObservedObject var model: StageModel

    private let rows: [(String, String)] = [
        ("Space", "Flip between Echo today and the option"),
        ("← →", "Switch the option in focus"),
        ("1 to 5", "Side by side, Overlay, Flip, Wipe, Matrix"),
        ("L / D", "Light or Dark"),
        ("R", "Redlines on or off"),
        ("S", "Next scenario"),
        ("⌘ Return", "Accept… (opens the confirmation sheet)"),
        ("⇧⌘ Return", "Send back…"),
        ("?", "This help"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Keyboard").font(.title3.weight(.semibold))
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 12) {
                    Text(rows[i].0)
                        .font(.callout.monospaced())
                        .frame(width: 90, alignment: .leading)
                    Text(rows[i].1).font(.callout)
                }
            }
            Text("Keys do nothing while you type in a note.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button {
                    model.send(.dismissSheet)
                } label: {
                    Text("Close")
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
