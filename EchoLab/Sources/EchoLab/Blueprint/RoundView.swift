import SwiftUI

/// A round page laid out from its blueprint.
struct RoundView: View {
    let pageID: String
    let round: RoundBlueprint

    @Environment(LabStore.self) private var store
    @State private var settings = LabStageSettings()

    private var page: LabPage { LabRegistry.page(id: pageID) ?? LabRegistry.pages[0] }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                    header(proxy)
                    LabStageControlBar(settings: settings)
                    ForEach(Array(round.topics.enumerated()), id: \.element.id) { index, topic in
                        RoundTopicView(page: page, topic: topic, number: index + 1, settings: settings)
                            .id(topic.id)
                    }
                    RoundPicksSummary(page: page, round: round)
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
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            Text(round.intro).font(TypographyTokens.prominent)
            HStack(spacing: SpacingTokens.xs) {
                ForEach(Array(round.topics.enumerated()), id: \.element.id) { index, topic in
                    Button("\(index + 1) · \(topic.title)") { withAnimation { proxy.scrollTo(topic.id, anchor: .top) } }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
    }
}

/// One topic: the question, how to try it, the options side by side, and your pick.
struct RoundTopicView: View {
    let page: LabPage
    let topic: RoundBlueprint.Topic
    let number: Int
    let settings: LabStageSettings

    @Environment(LabStore.self) private var store
    @State private var note = ""

    private var picked: String? { store.pick(page, topic: topic.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(number) · \(topic.title)").font(TypographyTokens.title3.weight(.semibold))
                Spacer()
                Text(pickLabel).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
            Text(topic.question).font(TypographyTokens.prominent)
            Label(topic.howToTry, systemImage: "hand.point.up.left")
                .font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 340, maximum: 620), spacing: SpacingTokens.md, alignment: .top)],
                      alignment: .leading, spacing: SpacingTokens.md) {
                ForEach(topic.options) { option in
                    RoundOptionCard(option: option, isPicked: picked == option.id, settings: settings) {
                        store.setPick(page, topic: topic.id, option: picked == option.id ? nil : option.id)
                    }
                }
            }
            HStack(spacing: SpacingTokens.sm) {
                Button(picked == "none" ? "None of these ✓" : "None of these") {
                    store.setPick(page, topic: topic.id, option: picked == "none" ? nil : "none")
                }
                .controlSize(.small)
                TextField("", text: $note, prompt: Text("Note: combine A with B, change something…"))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { store.setPickNote(page, topic: topic.id, note: note) }
                    .onChange(of: note) { _, new in store.setPickNote(page, topic: topic.id, note: new) }
            }
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.Surface.rest, in: .rect(cornerRadius: 14, style: .continuous))
        .onAppear { note = store.pickNote(page, topic: topic.id) }
    }

    private var pickLabel: String {
        guard let picked else { return "No pick yet" }
        if picked == "none" { return "None of these" }
        return "Your pick: \(topic.options.first { $0.id == picked }?.name ?? picked)"
    }
}

/// One option: name, what makes it different, the live specimen, and a Pick button.
struct RoundOptionCard: View {
    let option: RoundBlueprint.Option
    let isPicked: Bool
    let settings: LabStageSettings
    let pick: () -> Void

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
            Button(action: pick) {
                Label(isPicked ? "Picked" : "Pick this", systemImage: isPicked ? "checkmark.circle.fill" : "circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(isPicked ? ColorTokens.accent : nil)
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(isPicked ? ColorTokens.accent : ColorTokens.Workspace.cardEdge.opacity(0.5), lineWidth: isPicked ? 2 : 0.5))
    }
}

/// Your picks in one place, with the two things you can do about them.
struct RoundPicksSummary: View {
    let page: LabPage
    let round: RoundBlueprint

    @Environment(LabStore.self) private var store
    @State private var copied = false

    private var lines: [String] {
        round.topics.enumerated().map { index, topic in
            let picked = store.pick(page, topic: topic.id)
            let name = picked == nil ? "no pick" : (picked == "none" ? "none of these" : (topic.options.first { $0.id == picked }?.name ?? picked!))
            let note = store.pickNote(page, topic: topic.id)
            return "\(index + 1). \(topic.title): \(name)" + (note.isEmpty ? "" : " (\(note))")
        }
    }

    private var summary: String { "Picks for \(page.title)\n" + lines.joined(separator: "\n") }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Your picks").font(TypographyTokens.title3.weight(.semibold))
            ForEach(lines, id: \.self) { Text($0).font(TypographyTokens.standard) }
            HStack {
                Button("Accept these picks") { store.acceptPicks(page, summary: summary) }
                    .buttonStyle(.borderedProminent)
                Button("Send back as feedback") { store.sendFeedback(page, comment: summary) }
                Button(copied ? "Copied" : "Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(summary, forType: .string)
                    copied = true
                }
            }
            Text("Accepting tells the agent to build it into Echo. Sending back reopens it as new feedback. Your picks are saved as you make them.")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.Surface.rest, in: .rect(cornerRadius: 14, style: .continuous))
    }
}
