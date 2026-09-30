import SwiftUI

/// The selected element's properties as grouped cards, its states, and the way to give feedback.
struct SpecInspector: View {
    @Bindable var state: LabSpecState
    @Environment(\.labGiveFeedback) private var giveFeedback
    @Environment(\.labOpenRound) private var openRound

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                if let found = state.element(forSelection: state.selected) {
                    header(found.element, found.spec)
                    if !found.element.states.isEmpty { statePicker(found.element) }
                    ForEach(found.element.groups) { group in card(group) }
                    if !found.element.rounds.isEmpty { rounds(found.element) }
                    if !found.element.files.isEmpty { code(found.element) }
                } else if let area = state.area(forSelection: state.selected) {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text(area.title).font(TypographyTokens.title3.weight(.semibold))
                        Text(area.summary).foregroundStyle(ColorTokens.Text.secondary)
                        Text("This area has not been broken into numbered elements yet. Its overview is shown on the left.")
                            .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    }
                } else {
                    ContentUnavailableView("Nothing selected", systemImage: "cursorarrow.click",
                                           description: Text("Choose an element in the outline, or click a badge on the specimen."))
                }
            }
            .padding(SpacingTokens.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(ColorTokens.Background.secondary.opacity(0.5))
    }

    private func header(_ element: SpecElement, _ spec: AreaSpec) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(spec.id(element.number))
                .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(ColorTokens.accent)
            Text(element.name).font(TypographyTokens.title3.weight(.semibold))
            Text(element.summary).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if element.isRetired {
                Label("Retired: not in Echo", systemImage: "archivebox").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.warning)
            }
            Button("Feedback on \(spec.id(element.number))", systemImage: "text.bubble") { giveFeedback(spec.id(element.number), element.name) }
                .buttonStyle(.borderedProminent).controlSize(.small)
        }
    }

    private func statePicker(_ element: SpecElement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Preview a state")
            HStack(spacing: 6) {
                stateChip("Rest", key: nil)
                ForEach(element.states) { stateChip($0.name, key: $0.key) }
            }
            Text("Forces the specimen into that state so you don't have to hold the pointer there.")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
        }
    }

    private func stateChip(_ title: String, key: String?) -> some View {
        Button(title) { state.setPreview(key) }
            .buttonStyle(.bordered).controlSize(.small)
            .tint(state.previewState == key ? ColorTokens.accent : nil)
    }

    private func card(_ group: SpecGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(group.title)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { Divider() }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(row.label).foregroundStyle(ColorTokens.Text.secondary)
                            Spacer(minLength: 6)
                            if let swatch = row.swatch {
                                RoundedRectangle(cornerRadius: 3).fill(swatch).frame(width: 18, height: 12)
                                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.secondary.opacity(0.4), lineWidth: 0.5))
                            }
                            Text(row.value).fontWeight(.medium).multilineTextAlignment(.trailing).textSelection(.enabled)
                        }
                        if let token = row.token {
                            Text(token).font(.system(size: 10, design: .monospaced)).foregroundStyle(ColorTokens.Text.tertiary)
                                .frame(maxWidth: .infinity, alignment: .trailing).textSelection(.enabled)
                        }
                    }
                    .font(TypographyTokens.standard)
                    .padding(.horizontal, SpacingTokens.sm).padding(.vertical, 7)
                }
            }
            .background(ColorTokens.Surface.rest, in: .rect(cornerRadius: 10, style: .continuous))
        }
    }

    private func rounds(_ element: SpecElement) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Rounds that shaped it")
            ForEach(element.rounds, id: \.self) { id in
                if let page = LabRegistry.page(id: id) {
                    Button(page.title) { openRound(id) }.buttonStyle(.link).font(TypographyTokens.standard)
                }
            }
        }
    }

    private func code(_ element: SpecElement) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("In the code")
            ForEach(element.files, id: \.self) {
                Text($0).font(.system(size: 10, design: .monospaced)).foregroundStyle(ColorTokens.Text.secondary).textSelection(.enabled)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(ColorTokens.Text.tertiary)
    }
}
