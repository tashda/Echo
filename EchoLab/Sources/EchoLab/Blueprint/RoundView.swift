import SwiftUI

/// A round page laid out from its blueprint.
///
/// How you review a round: try every option, mark each one **Pick**, **Maybe** or **No**, add a
/// note anywhere, say **Needs more options** where nothing fits, then at the end **send it back**
/// or **accept**. Everything is saved as you go.
struct RoundView: View {
    let pageID: String
    let round: RoundBlueprint

    @Environment(LabStore.self) private var store
    @State private var settings = LabStageSettings.shared

    private var page: LabPage { LabRegistry.page(id: pageID) ?? LabRegistry.pages[0] }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                    header(proxy)
                    RoundHowTo()
                    LabStageControlBar(settings: settings)
                    ForEach(Array(round.topics.enumerated()), id: \.element.id) { index, topic in
                        RoundTopicView(page: page, topic: topic, number: index + 1, settings: settings).id(topic.id)
                    }
                    RoundReviewSummary(page: page, round: round)
                }
                .padding(SpacingTokens.lg)
                .frame(maxWidth: 1000, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func header(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            if let info = LabRounds.info(forPage: page.id) {
                Text("\(info.label) · \(info.date)")
                    .font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
            }
            Text(round.intro).font(TypographyTokens.prominent)
            HStack(spacing: SpacingTokens.xs) {
                ForEach(Array(round.topics.enumerated()), id: \.element.id) { index, topic in
                    TopicChip(page: page, topic: topic, number: index + 1) {
                        withAnimation { proxy.scrollTo(topic.id, anchor: .top) }
                    }
                }
            }
        }
    }
}

/// A jump chip that shows where the topic stands: nothing yet, picked, or needs more options.
private struct TopicChip: View {
    let page: LabPage
    let topic: RoundBlueprint.Topic
    let number: Int
    let action: () -> Void
    @Environment(LabStore.self) private var store

    var body: some View {
        let needsMore = store.needsMore(page, topic: topic.id)
        let picked = store.pick(page, topic: topic.id) != nil
        Button(action: action) {
            Label("\(number) · \(topic.title)", systemImage: needsMore ? "plus.circle" : (picked ? "checkmark.circle.fill" : "circle"))
        }
        .buttonStyle(.bordered).controlSize(.small)
        .tint(needsMore ? ColorTokens.Status.warning : (picked ? ColorTokens.Status.success : nil))
    }
}

/// Four steps, always visible, so it is clear what to do on a round page.
private struct RoundHowTo: View {
    private let steps: [(String, String)] = [
        ("hand.tap", "Try each option. They are live."),
        ("checkmark.circle", "Mark each one Pick, Maybe or No."),
        ("text.bubble", "Add a note on an option, a topic, or the whole round."),
        ("plus.circle", "Say Needs more options if nothing fits."),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.md) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                Label { Text("\(index + 1). \(step.1)") } icon: { Image(systemName: step.0) }
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Surface.rest, in: .rect(cornerRadius: 10, style: .continuous))
    }
}

/// One topic: the question, how to try it, the options side by side, and the topic's note.
struct RoundTopicView: View {
    let page: LabPage
    let topic: RoundBlueprint.Topic
    let number: Int
    let settings: LabStageSettings

    @Environment(LabStore.self) private var store
    @State private var note = ""

    var body: some View {
        let needsMore = store.needsMore(page, topic: topic.id)
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(number) · \(topic.title)").font(TypographyTokens.title3.weight(.semibold))
                Spacer()
                Text(statusText).font(TypographyTokens.detail)
                    .foregroundStyle(needsMore ? ColorTokens.Status.warning : ColorTokens.Text.secondary)
            }
            Text(topic.question).font(TypographyTokens.prominent)
            Label(topic.howToTry, systemImage: "hand.point.up.left")
                .font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 340, maximum: 620), spacing: SpacingTokens.md, alignment: .top)],
                      alignment: .leading, spacing: SpacingTokens.md) {
                ForEach(topic.options) { option in
                    RoundOptionCard(page: page, topicID: topic.id, option: option, settings: settings)
                }
            }
            HStack(alignment: .top, spacing: SpacingTokens.sm) {
                Toggle(isOn: Binding(get: { needsMore }, set: { store.setNeedsMore(page, topic: topic.id, $0) })) {
                    Label("Needs more options", systemImage: "plus.circle")
                }
                .toggleStyle(.button).controlSize(.small)
                .tint(needsMore ? ColorTokens.Status.warning : nil)
                TextField("", text: $note, prompt: Text(needsMore ? "What would you like to see instead?" : "Note on this topic, for example: combine A with B"), axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(1...4)
                    .onChange(of: note) { _, new in store.setPickNote(page, topic: topic.id, note: new) }
            }
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.Surface.rest, in: .rect(cornerRadius: 14, style: .continuous))
        .onAppear { note = store.pickNote(page, topic: topic.id) }
    }

    private var statusText: String {
        if store.needsMore(page, topic: topic.id) { return "Needs more options" }
        guard let picked = store.pick(page, topic: topic.id) else { return "Not decided yet" }
        return "Picked: \(topic.options.first { $0.id == picked }?.name ?? picked)"
    }
}

/// One option: what it is, the live specimen, then Pick / Maybe / No and an optional note.
struct RoundOptionCard: View {
    let page: LabPage
    let topicID: String
    let option: RoundBlueprint.Option
    let settings: LabStageSettings

    @Environment(LabStore.self) private var store
    @State private var note = ""
    @State private var showsNote = false

    private var verdict: LabStore.OptionVerdict? { store.verdict(page, topic: topicID, option: option.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xs) {
                Text(option.name).font(TypographyTokens.headline)
                if option.isEchoToday {
                    Text("Echo today").font(TypographyTokens.detail)
                        .padding(.horizontal, SpacingTokens.xs).padding(.vertical, 1)
                        .background(ColorTokens.Surface.hover, in: Capsule())
                }
                Spacer()
            }
            Text(option.summary).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            LabFitToWidth(designWidth: option.designWidth, designHeight: option.designHeight) {
                option.specimen().labStage(settings)
            }
            .padding(SpacingTokens.xs)
            .background(ColorTokens.Workspace.canvas, in: .rect(cornerRadius: 12, style: .continuous))
            .preferredColorScheme(settings.appearance.scheme)
            HStack(spacing: SpacingTokens.xs) {
                verdictButton("Pick", "checkmark.circle.fill", .pick, ColorTokens.Status.success)
                verdictButton("Maybe", "questionmark.circle", .maybe, ColorTokens.Status.warning)
                verdictButton("No", "xmark.circle", .no, ColorTokens.Status.error)
                Spacer()
                Button(showsNote || !note.isEmpty ? "Note" : "Add note", systemImage: "text.bubble") { showsNote.toggle() }
                    .buttonStyle(.plain).font(TypographyTokens.detail)
                    .foregroundStyle(note.isEmpty ? ColorTokens.Text.secondary : ColorTokens.accent)
            }
            if showsNote || !note.isEmpty {
                TextField("", text: $note, prompt: Text("Note on \(option.name)"), axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(1...4)
                    .onChange(of: note) { _, new in store.setOptionNote(page, topic: topicID, option: option.id, note: new) }
            }
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(border, lineWidth: verdict == .pick ? 2 : 0.5))
        .opacity(verdict == .no ? 0.7 : 1)
        .onAppear { note = store.optionNote(page, topic: topicID, option: option.id); showsNote = !note.isEmpty }
    }

    private var border: Color {
        switch verdict {
        case .pick: ColorTokens.Status.success
        case .maybe: ColorTokens.Status.warning
        case .no: ColorTokens.Status.error.opacity(0.6)
        case nil: ColorTokens.Workspace.cardEdge.opacity(0.5)
        }
    }

    private func verdictButton(_ title: String, _ symbol: String, _ value: LabStore.OptionVerdict, _ tint: Color) -> some View {
        let isOn = verdict == value
        return Button {
            store.setVerdict(page, topic: topicID, option: option.id, verdict: isOn ? nil : value)
        } label: {
            Label(title, systemImage: symbol)
        }
        .buttonStyle(.bordered).controlSize(.small)
        .tint(isOn ? tint : nil)
        .fontWeight(isOn ? .semibold : .regular)
    }
}

/// Your review in one place: progress, a note on the whole round, and what to do with it.
struct RoundReviewSummary: View {
    let page: LabPage
    let round: RoundBlueprint

    @Environment(LabStore.self) private var store
    @State private var general = ""
    @State private var copied = false

    private var decided: Int { round.topics.filter { store.pick(page, topic: $0.id) != nil }.count }
    private var needMore: Int { round.topics.filter { store.needsMore(page, topic: $0.id) }.count }
    private var canAccept: Bool { round.topics.allSatisfy { store.pick(page, topic: $0.id) != nil } && needMore == 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Your review").font(TypographyTokens.title3.weight(.semibold))
            Text("\(decided) of \(round.topics.count) topics decided" + (needMore > 0 ? " · \(needMore) need more options" : ""))
                .font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
            ForEach(Array(summaryLines.enumerated()), id: \.offset) { _, line in
                Text(line).font(TypographyTokens.standard).fixedSize(horizontal: false, vertical: true)
            }
            TextField("", text: $general, prompt: Text("Notes on the whole round, anything not tied to one option"), axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(2...6)
                .onChange(of: general) { _, new in store.setGeneralNote(page, new) }
            HStack {
                Button("Accept these picks") { store.acceptPicks(page, summary: summary) }
                    .buttonStyle(.borderedProminent).disabled(!canAccept)
                    .help(canAccept ? "Tell the agent to build the picks into Echo" : "Pick one option in every topic, and clear Needs more options, to accept")
                Button("Send back to Claude") { store.sendFeedback(page, comment: summary) }
                    .help("Send your marks and notes as feedback so options can be added or changed")
                Button(copied ? "Copied" : "Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(summary, forType: .string)
                    copied = true
                }
            }
            Text("Everything you mark is saved as you go. Accept needs a pick in every topic. Send back reopens the round with your marks and notes for Claude to act on.")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.Surface.rest, in: .rect(cornerRadius: 14, style: .continuous))
        .onAppear { general = store.generalNote(page) }
    }

    private var summaryLines: [String] {
        round.topics.enumerated().map { index, topic in
            var parts: [String] = []
            for option in topic.options {
                switch store.verdict(page, topic: topic.id, option: option.id) {
                case .pick: parts.append("picked \(option.name)")
                case .maybe: parts.append("maybe \(option.name)")
                case .no: parts.append("no \(option.name)")
                case nil: break
                }
                let note = store.optionNote(page, topic: topic.id, option: option.id)
                if !note.isEmpty { parts.append("note on \(option.name): \(note)") }
            }
            if store.needsMore(page, topic: topic.id) { parts.append("NEEDS MORE OPTIONS") }
            let topicNote = store.pickNote(page, topic: topic.id)
            if !topicNote.isEmpty { parts.append("note: \(topicNote)") }
            return "\(index + 1). \(topic.title): " + (parts.isEmpty ? "no answer yet" : parts.joined(separator: "; "))
        }
    }

    private var summary: String {
        var text = "Review of \(page.title)\n" + summaryLines.joined(separator: "\n")
        let general = store.generalNote(page)
        if !general.isEmpty { text += "\nOverall: \(general)" }
        return text
    }
}
