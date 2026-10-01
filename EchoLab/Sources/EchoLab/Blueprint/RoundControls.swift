import SwiftUI

/// A control as a labelled menu that shows its current choice and what it means.
private struct RoundControlMenu: View {
    let page: LabPage
    let control: RoundSpec.Control
    let values: RoundValues
    var showsSummary = true
    @Environment(LabStore.self) private var store

    var body: some View {
        let current = control.choices.first { $0.id == values[control.id] }
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(control.title).font(TypographyTokens.standard.weight(.semibold)).foregroundStyle(ColorTokens.Text.primary)
                if store.isNew(page, addedIn: control.addedIn) { LabNewBadge() }
            }
            Menu {
                Picker(control.title, selection: values.binding(control.id)) {
                    ForEach(control.choices) {
                        Text($0.name + ($0.id == control.recommended ? "  ★ recommended" : "") + (store.isNew(page, addedIn: $0.addedIn) ? "  · new" : "")).tag($0.id)
                    }
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
struct RoundControlsColumn: View {
    let page: LabPage
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
                if !spec.actions.isEmpty {
                    section("Actions", "play.circle") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 6) {
                            ForEach(spec.actions) { action in
                                Button { action.perform(values) } label: { Label(action.title, systemImage: action.symbol) }
                                    .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, prominent: true))
                            }
                        }
                    }
                }
                section("Controls", "slider.horizontal.3") {
                    VStack(alignment: .leading, spacing: SpacingTokens.md) {
                        ForEach(spec.controls) { RoundControlMenu(page: page, control: $0, values: values) }
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
struct RoundControlsBar: View {
    let page: LabPage
    let spec: RoundSpec
    let values: RoundValues
    let settings: LabStageSettings

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            if !spec.controls.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: SpacingTokens.sm)], alignment: .leading, spacing: SpacingTokens.xs) {
                    ForEach(spec.controls) { RoundControlMenu(page: page, control: $0, values: values, showsSummary: false) }
                }
            }
            LabStageControlBar(settings: settings)
        }
        .controlSize(.small)
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Surface.rest, in: .rect(cornerRadius: 12, style: .continuous))
    }
}
