import SwiftUI

/// The one header of a round page, in a box: which round, its status, what it asks, and how the
/// page works.
struct LabRoundInfoBox: View {
    let page: LabPage
    var hint = false
    @Environment(LabStore.self) private var store
    @AppStorage("lab.round.infoExpanded") private var expanded = true

    var body: some View {
        let info = LabRounds.info(forPage: page.id)
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xs) {
                if let tag = info.flatMap({ LabRoundName.split($0.label).tag }) { LabRoundBadge(tag: tag) }
                Text([info?.date, LabAreas.areaID(ofPage: page.id).flatMap { LabAreas.area(id: $0)?.title }]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                Spacer()
                if let status = store.status(of: page) { LabStatusPill(status: status) }
                if hint {
                    Button(expanded ? "Collapse" : "Expand", systemImage: expanded ? "chevron.up" : "chevron.down") { expanded.toggle() }
                        .labelStyle(.iconOnly).buttonStyle(.borderless).controlSize(.small)
                }
            }
            Text(LabRoundName.split(page.title).name).font(TypographyTokens.title2.weight(.semibold))
            if !page.summary.isEmpty, expanded || !hint {
                Text(page.summary).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if hint, expanded {
                HStack(spacing: SpacingTokens.md) {
                    hintStep("1", "Try things here")
                    hintStep("2", "Decide in the panel on the right")
                    hintStep("3", "Accept, or send back, at the bottom of that panel")
                }
                .padding(.top, 2)
            }
        }
        .padding(SpacingTokens.md)
        // Wrapping text asked for its minimum size is measured at zero width, one word per line,
        // which made the window's minimum height thousands of points. A minimum width prevents it.
        .frame(minWidth: 420, maxWidth: .infinity, alignment: .leading)
        .labCard(cornerRadius: 16)
    }

    private func hintStep(_ number: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Text(number).font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                .frame(width: 16, height: 16).background(ColorTokens.accent, in: Circle())
            Text(text).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
        }
    }
}

/// Your decision: a card per topic, "Use what's selected in the preview", and the summary.
struct RoundDecisionPanel: View {
    let page: LabPage
    let decision: RoundDecision
    @Environment(LabStore.self) private var store

    private var hasPreview: Bool { decision.topics.contains { $0.preview != nil } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                RoundWhatsNew(page: page, decision: decision)
                HStack {
                    Label("Your decision", systemImage: "checkmark.seal").font(TypographyTokens.headline)
                    Spacer()
                    Text("\(decided) of \(decision.topics.count)").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                }
                if decision.topics.contains(where: { $0.recommended != nil }) {
                    Button {
                        for topic in decision.topics { if let rec = topic.recommended { store.setPick(page, topic: topic.id, option: rec) } }
                    } label: {
                        Label("Use all recommendations", systemImage: "star.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, isOn: true))
                    .help("Picks the agent's recommendation for every topic; change any you disagree with")
                }
                if hasPreview {
                    Button {
                        for topic in decision.topics { if let value = topic.preview?() { store.setPick(page, topic: topic.id, option: value) } }
                    } label: {
                        Label("Use what's selected in the preview", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, prominent: true))
                    .help("Picks, for every topic that has a control in the playground, the choice you currently have set there")
                }
                ForEach(Array(decision.topics.enumerated()), id: \.element.id) { index, topic in
                    RoundDecisionTopicCard(page: page, topic: topic, number: index + 1)
                }
                RoundDecisionSummary(page: page, decision: decision)
            }
            .padding(SpacingTokens.sm)
        }
        .labScrollSizing()
        .background(ColorTokens.Workspace.canvas)
    }

    private var decided: Int { decision.topics.filter { store.pick(page, topic: $0.id) != nil }.count }
}

private struct RoundDecisionTopicCard: View {
    let page: LabPage
    let topic: RoundDecision.Topic
    let number: Int
    @Environment(LabStore.self) private var store
    @State private var note = ""

    var body: some View {
        let picked = store.pick(page, topic: topic.id)
        let needsMore = store.needsMore(page, topic: topic.id)
        let previewChoice = topic.preview?()
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(number) · \(topic.title)").font(TypographyTokens.standard.weight(.semibold))
                if store.isNew(page, addedIn: topic.addedIn) { LabNewBadge() }
                Spacer()
                if needsMore { Text("Needs more").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.warning) }
            }
            Text(topic.question).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let rec = topic.recommended, let name = topic.choices.first(where: { $0.id == rec })?.name {
                VStack(alignment: .leading, spacing: 2) {
                    Label("I recommend: \(name)", systemImage: "star.fill").font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.accent)
                    if let why = topic.why {
                        Text(why).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(SpacingTokens.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.accent.opacity(0.08), in: .rect(cornerRadius: 8, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                ForEach(topic.choices) { choice in
                    Button {
                        store.setPick(page, topic: topic.id, option: picked == choice.id ? nil : choice.id)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: picked == choice.id ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(picked == choice.id ? ColorTokens.accent : ColorTokens.Text.tertiary)
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 5) {
                                    Text(choice.name).font(TypographyTokens.standard)
                                    if store.isNew(page, addedIn: choice.addedIn) { LabNewBadge() }
                                }
                                if let summary = choice.summary {
                                    Text(summary).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 4)
                            if topic.recommended == choice.id {
                                Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(ColorTokens.accent).help("Recommended")
                            }
                            if previewChoice == choice.id {
                                Text("in preview").font(.system(size: 10)).padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(ColorTokens.Surface.hover, in: Capsule()).foregroundStyle(ColorTokens.Text.secondary)
                            }
                        }
                        .padding(.vertical, 2).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 6) {
                if let rec = topic.recommended, rec != picked {
                    Button { store.setPick(page, topic: topic.id, option: rec) } label: { Label("Use recommendation", systemImage: "star") }
                        .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent))
                }
                if let previewChoice, previewChoice != picked {
                    Button { store.setPick(page, topic: topic.id, option: previewChoice) } label: { Label("Use preview", systemImage: "wand.and.stars") }
                        .buttonStyle(LabPillButtonStyle())
                }
                Button { store.setNeedsMore(page, topic: topic.id, !needsMore) } label: {
                    Label("Needs more options", systemImage: needsMore ? "checkmark.circle.fill" : "plus.circle")
                }
                .buttonStyle(LabPillButtonStyle(tint: ColorTokens.Status.warning, isOn: needsMore))
            }
            TextField("", text: $note, prompt: Text(needsMore ? "What would you like to see instead?" : "Note"), axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(1...4).font(TypographyTokens.standard)
                .onChange(of: note) { _, new in store.setPickNote(page, topic: topic.id, note: new) }
        }
        .padding(SpacingTokens.sm)
        .labCard(cornerRadius: 14)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(needsMore ? ColorTokens.Status.warning : (picked != nil ? ColorTokens.Status.success : .clear), lineWidth: picked != nil || needsMore ? 1.5 : 0))
        .onAppear { note = store.pickNote(page, topic: topic.id) }
    }
}

private struct RoundDecisionSummary: View {
    let page: LabPage
    let decision: RoundDecision
    @Environment(LabStore.self) private var store
    @State private var general = ""
    @State private var copied = false

    private var canAccept: Bool {
        decision.topics.allSatisfy { store.pick(page, topic: $0.id) != nil } && !decision.topics.contains { store.needsMore(page, topic: $0.id) }
    }

    private var lines: [String] {
        decision.topics.enumerated().map { index, topic in
            var parts: [String] = []
            if let picked = store.pick(page, topic: topic.id) { parts.append("picked \(topic.choices.first { $0.id == picked }?.name ?? picked)") }
            for choice in topic.choices {
                switch store.verdict(page, topic: topic.id, option: choice.id) {
                case .maybe: parts.append("maybe \(choice.name)")
                case .no: parts.append("no \(choice.name)")
                default: break
                }
                let choiceNote = store.optionNote(page, topic: topic.id, option: choice.id)
                if !choiceNote.isEmpty { parts.append("note on \(choice.name): \(choiceNote)") }
            }
            if store.needsMore(page, topic: topic.id) { parts.append("NEEDS MORE OPTIONS") }
            let note = store.pickNote(page, topic: topic.id)
            if !note.isEmpty { parts.append("note: \(note)") }
            return "\(index + 1). \(topic.title): " + (parts.isEmpty ? "no answer yet" : parts.joined(separator: "; "))
        }
    }

    private var summary: String {
        var text = "Review of \(page.title)\n" + lines.joined(separator: "\n")
        let general = store.generalNote(page)
        if !general.isEmpty { text += "\nOverall: \(general)" }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Anything else").font(TypographyTokens.standard.weight(.semibold))
            TextField("", text: $general, prompt: Text("Notes on the whole round"), axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(2...6).font(TypographyTokens.standard)
                .onChange(of: general) { _, new in store.setGeneralNote(page, new) }
            HStack {
                Button("Accept") { store.acceptPicks(page, summary: summary) }
                    .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, prominent: true)).disabled(!canAccept)
                    .help("Needs a pick in every topic and no topic marked Needs more options")
                Button("Send back") { store.sendFeedback(page, comment: summary) }
                    .buttonStyle(LabPillButtonStyle())
                    .help("Send your picks and notes to Claude as feedback")
                Button(copied ? "Copied" : "Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(summary, forType: .string)
                    copied = true
                }
                .buttonStyle(LabPillButtonStyle())
            }
            Text("Saved as you go. Accept needs a pick in every topic.").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
        }
        .padding(SpacingTokens.sm)
        .onAppear { general = store.generalNote(page) }
    }
}
