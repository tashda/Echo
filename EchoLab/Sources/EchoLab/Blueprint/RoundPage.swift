import SwiftUI

/// A round page laid out from a `RoundSpec`: the info box, the controls, the exhibits (which wrap
/// to the window, so nothing scrolls sideways), and "Your decision".
struct LabRoundPage: View {
    let pageID: String
    let spec: RoundSpec

    @State private var values: RoundValues
    @State private var settings = LabStageSettings.shared

    init(pageID: String, spec: RoundSpec) {
        self.pageID = pageID
        self.spec = spec
        _values = State(initialValue: RoundValues.shared(pageID: pageID, controls: spec.controls))
    }

    private var page: LabPage { LabRegistry.page(id: pageID) ?? LabRegistry.pages[0] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                LabRoundInfoBox(page: page, hint: true)
                tryIt
            }
            .padding(SpacingTokens.md)
        }
    }

    // MARK: Try it

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Label("Try it", systemImage: "hand.tap").font(TypographyTokens.headline)
            controlsCard
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320, maximum: 720), spacing: SpacingTokens.sm, alignment: .top)],
                      alignment: .leading, spacing: SpacingTokens.sm) {
                ForEach(spec.exhibits) { exhibit in
                    RoundExhibitCard(page: page, exhibit: exhibit, values: values, settings: settings, decides: spec.exhibitTopic != nil)
                }
            }
        }
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            if !spec.controls.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: SpacingTokens.sm)], alignment: .leading, spacing: SpacingTokens.xs) {
                    ForEach(spec.controls) { control in
                        LabeledContent(control.title) {
                            Menu {
                                Picker(control.title, selection: values.binding(control.id)) {
                                    ForEach(control.choices) { Text($0.name).tag($0.id) }
                                }
                                .pickerStyle(.inline)
                            } label: {
                                Text(control.choices.first { $0.id == values[control.id] }?.name ?? control.defaultChoice)
                            }
                            .fixedSize()
                        }
                    }
                }
            }
            LabStageControlBar(settings: settings)
        }
        .controlSize(.small)
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Surface.rest, in: .rect(cornerRadius: 12, style: .continuous))
    }
}

/// One exhibit: title, what makes it different, the live specimen, and (when the round picks
/// between exhibits) Pick, Maybe, No and a note.
private struct RoundExhibitCard: View {
    let page: LabPage
    let exhibit: RoundSpec.Exhibit
    let values: RoundValues
    let settings: LabStageSettings
    let decides: Bool

    @Environment(LabStore.self) private var store
    @State private var note = ""
    @State private var showsNote = false

    private var verdict: LabStore.OptionVerdict? { store.verdict(page, topic: RoundSpec.exhibitTopicID, option: exhibit.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xs) {
                Text(exhibit.title).font(TypographyTokens.headline)
                if exhibit.isEchoToday {
                    Text("Echo today").font(TypographyTokens.detail)
                        .padding(.horizontal, SpacingTokens.xs).padding(.vertical, 1)
                        .background(ColorTokens.Surface.hover, in: Capsule())
                }
                Spacer()
            }
            if !exhibit.summary.isEmpty {
                Text(exhibit.summary).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LabFitToWidth(designWidth: exhibit.designWidth, designHeight: exhibit.designHeight) {
                exhibit.build(values).labStage(settings)
            }
            .padding(SpacingTokens.xs)
            .background(ColorTokens.Workspace.canvas, in: .rect(cornerRadius: 12, style: .continuous))
            .preferredColorScheme(settings.appearance.scheme)
            if decides {
                HStack(spacing: SpacingTokens.xs) {
                    mark("Pick", "checkmark.circle.fill", .pick, ColorTokens.Status.success)
                    mark("Maybe", "questionmark.circle", .maybe, ColorTokens.Status.warning)
                    mark("No", "xmark.circle", .no, ColorTokens.Status.error)
                    Spacer()
                    Button(showsNote || !note.isEmpty ? "Note" : "Add note", systemImage: "text.bubble") { showsNote.toggle() }
                        .buttonStyle(.plain).font(TypographyTokens.detail)
                        .foregroundStyle(note.isEmpty ? ColorTokens.Text.secondary : ColorTokens.accent)
                }
                if showsNote || !note.isEmpty {
                    TextField("", text: $note, prompt: Text("Note on \(exhibit.title)"), axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(1...4)
                        .onChange(of: note) { _, new in store.setOptionNote(page, topic: RoundSpec.exhibitTopicID, option: exhibit.id, note: new) }
                }
            }
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(border, lineWidth: verdict == .pick ? 2 : 0.5))
        .opacity(verdict == .no ? 0.7 : 1)
        .onAppear {
            note = store.optionNote(page, topic: RoundSpec.exhibitTopicID, option: exhibit.id)
            showsNote = !note.isEmpty
        }
    }

    private var border: Color {
        switch verdict {
        case .pick: ColorTokens.Status.success
        case .maybe: ColorTokens.Status.warning
        case .no: ColorTokens.Status.error.opacity(0.6)
        case nil: ColorTokens.Workspace.cardEdge.opacity(0.5)
        }
    }

    private func mark(_ title: String, _ symbol: String, _ value: LabStore.OptionVerdict, _ tint: Color) -> some View {
        let isOn = verdict == value
        return Button {
            store.setVerdict(page, topic: RoundSpec.exhibitTopicID, option: exhibit.id, verdict: isOn ? nil : value)
        } label: { Label(title, systemImage: symbol) }
            .buttonStyle(.bordered).controlSize(.small)
            .tint(isOn ? tint : nil).fontWeight(isOn ? .semibold : .regular)
    }
}
