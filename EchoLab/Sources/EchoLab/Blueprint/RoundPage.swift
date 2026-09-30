import SwiftUI

/// A round page laid out from a `RoundSpec` as a workbench: controls (with presets) on the left,
/// the exhibits in the middle where they stay put and wrap to the width, and the decision in the
/// right-hand panel. Every part scrolls on its own, so you never lose the previews while you
/// change a control. A round with only a few controls gets a slim bar above the exhibits instead.
struct LabRoundPage: View {
    let pageID: String
    let spec: RoundSpec

    @State private var values: RoundValues
    @State private var settings = LabStageSettings.shared
    @AppStorage("lab.round.showsControls") private var showsControls = true

    init(pageID: String, spec: RoundSpec) {
        self.pageID = pageID
        self.spec = spec
        _values = State(initialValue: RoundValues.shared(pageID: pageID, controls: spec.controls))
    }

    private var page: LabPage { LabRegistry.page(id: pageID) ?? LabRegistry.pages[0] }
    private var usesColumn: Bool { (spec.controls.count > 4 || !spec.presets.isEmpty) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LabRoundInfoBox(page: page, hint: true).padding([.horizontal, .top], SpacingTokens.md).padding(.bottom, SpacingTokens.xs)
            HStack(alignment: .top, spacing: 0) {
                if usesColumn && showsControls {
                    RoundControlsColumn(spec: spec, values: values, settings: settings).frame(width: 290)
                    Divider()
                }
                canvas
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var canvas: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if usesColumn {
                    Button { showsControls.toggle() } label: {
                        Label(showsControls ? "Hide controls" : "Show controls", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(LabPillButtonStyle(isOn: showsControls))
                }
                Label("Try it", systemImage: "hand.tap").font(TypographyTokens.headline)
                Spacer()
            }
            .padding(.horizontal, SpacingTokens.md).padding(.vertical, SpacingTokens.xs)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    if !usesColumn { RoundControlsBar(spec: spec, values: values, settings: settings) }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320, maximum: 720), spacing: SpacingTokens.sm, alignment: .top)],
                              alignment: .leading, spacing: SpacingTokens.sm) {
                        ForEach(spec.exhibits) { exhibit in
                            RoundExhibitCard(page: page, exhibit: exhibit, values: values, settings: settings, decides: spec.exhibitTopic != nil,
                                     recommendation: spec.exhibitTopic.flatMap { $0.recommended == exhibit.id ? $0.why : nil })
                        }
                    }
                }
                .padding(SpacingTokens.md)
            }
        }
        .labScrollSizing()
    }
}

/// A control as a labelled menu that shows its current choice and what it means.
private struct RoundControlMenu: View {
    let control: RoundSpec.Control
    let values: RoundValues
    var showsSummary = true

    var body: some View {
        let current = control.choices.first { $0.id == values[control.id] }
        VStack(alignment: .leading, spacing: 3) {
            Text(control.title).font(TypographyTokens.standard.weight(.semibold)).foregroundStyle(ColorTokens.Text.primary)
            Menu {
                Picker(control.title, selection: values.binding(control.id)) {
                    ForEach(control.choices) { Text($0.name + ($0.id == control.recommended ? "  ★ recommended" : "")).tag($0.id) }
                }
                .pickerStyle(.inline)
            } label: {
                HStack {
                    Text(current?.name ?? control.defaultChoice).lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 9)).foregroundStyle(ColorTokens.Text.tertiary)
                }
                .font(TypographyTokens.standard)
                .padding(.horizontal, 10).frame(height: 30)
                .labField()
                .contentShape(Rectangle())
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden)
            if let rec = control.recommended, current?.id != rec, let name = control.choices.first(where: { $0.id == rec })?.name {
                Label("Recommended: \(name)", systemImage: "star.fill").font(TypographyTokens.detail.weight(.medium)).foregroundStyle(ColorTokens.accent)
            }
            if showsSummary, let summary = current?.summary {
                Text(summary).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The left column: presets, every control, and the test controls.
private struct RoundControlsColumn: View {
    let spec: RoundSpec
    let values: RoundValues
    let settings: LabStageSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                if !spec.presets.isEmpty {
                    section("Presets", "wand.and.stars") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 6) {
                            ForEach(spec.presets) { preset in
                                Button { values.apply(preset) } label: {
                                    HStack(spacing: 4) {
                                        Text(preset.name)
                                        if preset.isRecommended { Image(systemName: "star.fill").font(.system(size: 9)) }
                                    }
                                }
                                .buttonStyle(LabPillButtonStyle(isOn: values.matches(preset)))
                                .help(preset.summary ?? "")
                            }
                        }
                    }
                }
                section("Controls", "slider.horizontal.3") {
                    VStack(alignment: .leading, spacing: SpacingTokens.md) {
                        ForEach(spec.controls) { RoundControlMenu(control: $0, values: values) }
                        Button { values.reset(spec.controls) } label: { Label("Reset controls", systemImage: "arrow.uturn.backward") }
                            .buttonStyle(LabPillButtonStyle())
                    }
                }
                section("Test", "testtube.2") { LabStageControlColumn(settings: settings) }
            }
            .padding(SpacingTokens.md)
        }
        .labScrollSizing()
        .background(ColorTokens.Workspace.canvas)
    }

    private func section<Content: View>(_ title: String, _ symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            LabColumnTitle(text: title, symbol: symbol)
            content()
        }
    }
}

/// The slim bar used when a round has only a few controls.
private struct RoundControlsBar: View {
    let spec: RoundSpec
    let values: RoundValues
    let settings: LabStageSettings

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            if !spec.controls.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: SpacingTokens.sm)], alignment: .leading, spacing: SpacingTokens.xs) {
                    ForEach(spec.controls) { RoundControlMenu(control: $0, values: values, showsSummary: false) }
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
    /// The agent's reason, set when this exhibit is the recommended one.
    var recommendation: String?

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
                if recommendation != nil {
                    Label("Recommended", systemImage: "star.fill").font(TypographyTokens.detail.weight(.semibold))
                        .padding(.horizontal, SpacingTokens.xs).padding(.vertical, 1)
                        .background(ColorTokens.accent.opacity(0.14), in: Capsule()).foregroundStyle(ColorTokens.accent)
                }
                Spacer()
            }
            if let recommendation {
                Text(recommendation).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
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
        .labCard(cornerRadius: 16)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(border, lineWidth: verdict == nil ? 0 : 2))
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
        case nil: .clear
        }
    }

    private func mark(_ title: String, _ symbol: String, _ value: LabStore.OptionVerdict, _ tint: Color) -> some View {
        let isOn = verdict == value
        return Button {
            store.setVerdict(page, topic: RoundSpec.exhibitTopicID, option: exhibit.id, verdict: isOn ? nil : value)
        } label: { Label(title, systemImage: symbol) }
            .buttonStyle(LabPillButtonStyle(tint: tint, isOn: isOn))
    }
}
