import SwiftUI
import StageCore

/// Right panel (decisions H11, H12): one card per question, then pinned notes, the general note, Accept and Send back.
struct DecisionPanel: View {
    @ObservedObject var model: StageModel

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                header
                newSinceCard
                ForEach(model.manifest.decisions, id: \.id) { decision in
                    DecisionCard(model: model, decision: decision)
                }
                pinnedNotes
                generalNote
                actions
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your decision").font(.headline)
            if !model.manifest.summary.isEmpty {
                Text(model.manifest.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            StageFlow(spacing: 6) {
                Button {
                    model.send(.useAllRecommendations)
                } label: {
                    Label("Use all recommendations", systemImage: "star")
                }
                .buttonStyle(.glass)
                Button {
                    model.send(.useAllPreview)
                } label: {
                    Label("Use what's in the preview", systemImage: "eye")
                }
                .buttonStyle(.glass)
            }
        }
    }

    @ViewBuilder
    private var newSinceCard: some View {
        let items = model.manifest.newItems
        let seen: Bool = (model.state.seenRevision ?? 0) >= model.manifest.revision
        if !items.isEmpty && !seen {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("New since your last review").font(.callout.weight(.semibold))
                    NewBadge()
                    Spacer()
                    Button("Mark as seen") { model.send(.markRevisionSeen) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Hide this card. The NEW badges stay.")
                }
                ForEach(items, id: \.self) { item in
                    Text("• \(item)").font(.caption)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.10)))
        }
        laterRevisionsCard
    }

    /// Compare revisions (decision H15): while an earlier revision is in view, what the later ones added.
    @ViewBuilder
    private var laterRevisionsCard: some View {
        if model.isViewingEarlierRevision {
            let later = model.latestManifest.additions(after: model.manifest.revision)
            VStack(alignment: .leading, spacing: 4) {
                Text("Added after revision \(model.manifest.revision)").font(.callout.weight(.semibold))
                if later.isEmpty {
                    Text("Nothing was added. Later revisions changed the code of existing options, which this view cannot show.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(later, id: \.self) { item in
                    Text("• \(item)").font(.caption)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.10)))
        }
    }

    // MARK: Pinned notes

    @ViewBuilder
    private var pinnedNotes: some View {
        if !model.state.pins.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Pinned notes")
                ForEach(model.state.pins, id: \.id) { pin in
                    PinRow(model: model, pin: pin)
                }
            }
        }
    }

    private var generalNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("General note")
            TextField("Notes on the whole Proposal", text: model.binding({ $0.generalNote }, { StageAction.setGeneralNote($0) }), axis: .vertical)
                .lineLimit(2...6)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button {
                    model.send(.commitGeneralNote)
                } label: {
                    Text("Send note")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.state.generalNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 6) {
            Button {
                model.send(.requestAccept)
            } label: {
                Label("Accept…", systemImage: "checkmark").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.glassProminent)
            Button {
                model.send(.requestSendBack)
            } label: {
                Label("Send back…", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.glass)
            Button {
                model.send(.requestAsk)
            } label: {
                Label("Ask Hatch", systemImage: "questionmark.bubble").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
        .padding(.top, 4)
    }
}

struct PinRow: View {
    @ObservedObject var model: StageModel
    let pin: StagePin

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                model.send(.openPin(pin.id))
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    PinBadge(number: pin.number)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pin.text).font(.callout).multilineTextAlignment(.leading)
                        Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Open the stage the way it was when you wrote this.")
            Spacer(minLength: 0)
            Button {
                model.send(.removePin(pin.id))
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.plain)
            .help("Delete this pin")
        }
    }

    private var subtitle: String {
        let scenario = model.manifest.effectiveScenarios.first(where: { $0.id == pin.scenario })?.title ?? pin.scenario
        return "\(scenario) · \(pin.appearance.title) · Corners \(pin.corners) · \(StageZoom.label(scale: pin.zoom))"
    }
}

struct PinBadge: View {
    let number: Int

    var body: some View {
        Text("\(number)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.white)
            .frame(width: 18, height: 18)
            .background(Circle().fill(Color.red))
    }
}

/// One question: the recommendation with its reason, radio choices, and the buttons that set the answer.
struct DecisionCard: View {
    @ObservedObject var model: StageModel
    let decision: StageDecision

    private var answer: String? { model.state.answers[decision.id] }

    private var recommendedName: String? {
        guard let r = decision.recommended else { return nil }
        return decision.choiceName(r)
    }

    /// The choice the preview is showing right now, if this decision has one.
    private var previewChoice: String? {
        switch decision.source {
        case .control:
            return model.state.controlValue(decision.id, in: model.manifest)
        case .specimens:
            if let c = model.selectedColumn, c.kind == .option { return c.specimenID }
            return nil
        case .question:
            return nil
        }
    }

    private var statusText: String {
        if model.state.needsMore.contains(decision.id) { return "Needs more options" }
        if let a = answer { return a == decision.recommended ? "Decided · recommendation" : "Decided" }
        return "Undecided"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(decision.title).font(.callout.weight(.semibold))
                if model.manifest.isNew(addedIn: decision.addedIn) { NewBadge() }
                Spacer()
                Text(statusText).font(.caption2).foregroundStyle(.secondary)
            }
            if !decision.question.isEmpty {
                Text(decision.question).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            choices
            recommendation
            buttons
            noteField
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(answer == nil ? Color.clear : Color.accentColor.opacity(0.5), lineWidth: 1))
    }

    private var choices: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(decision.choices, id: \.id) { choice in
                choiceRow(choice)
            }
        }
    }

    private func choiceRow(_ choice: StageChoice) -> some View {
        let selected: Bool = answer == choice.id
        let symbol: String = selected ? "largecircle.fill.circle" : "circle"
        return Button {
            model.send(.answer(topic: decision.id, choice: choice.id))
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                Text(choice.name).font(.callout)
                if decision.recommended == choice.id { Text("★").foregroundStyle(Color.orange) }
                if model.manifest.isNew(addedIn: choice.addedIn) { NewBadge() }
                if previewChoice == choice.id {
                    Text("in preview")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(Color.secondary.opacity(0.2)))
                }
                if decision.source == .specimens, let v = model.state.verdicts[choice.id] {
                    Text(v.title).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var recommendation: some View {
        if let name = recommendedName {
            let because: String = (decision.why ?? "").isEmpty ? "" : " because \(decision.why ?? "")"
            Text("Hatch recommends \(name)\(because)")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var buttons: some View {
        StageFlow(spacing: 6) {
            Button {
                model.send(.useRecommendation(topic: decision.id))
            } label: {
                Text("Use recommendation")
            }
            .disabled(decision.recommended == nil || answer == decision.recommended)
            if decision.source != .question {
                Button {
                    model.send(.usePreview(topic: decision.id))
                } label: {
                    Text("Use what's in preview")
                }
                .disabled(previewChoice == nil || answer == previewChoice)
            }
            Button {
                model.send(.setNeedsMore(topic: decision.id, on: !model.state.needsMore.contains(decision.id)))
            } label: {
                Text(model.state.needsMore.contains(decision.id) ? "Needs more options ✓" : "Needs more options")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var noteField: some View {
        TextField(
            "Note on this question (Return to send)",
            text: model.binding({ $0.topicNotes[decision.id] ?? "" }, { StageAction.setTopicNote(topic: decision.id, text: $0) })
        )
        .textFieldStyle(.roundedBorder)
        .font(.caption)
        .onSubmit { model.send(.commitTopicNote(topic: decision.id)) }
    }
}
