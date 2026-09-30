import EchoSenseScenarios
import SwiftUI

/// One expected title: its place in the expectation, a grip to drag it by, and where the popup has it now.
struct ScenarioExpectedRow: View {
    let position: Int
    let title: String
    /// Where the popup has it now; nil when it isn't offered.
    let rank: Int?
    let remove: () -> Void

    var body: some View {
        let inPlace = rank == position
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "line.3.horizontal").foregroundStyle(ColorTokens.Text.tertiary).help("Drag to reorder")
            Text("\(position)").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.secondary).frame(width: 18, alignment: .trailing)
            Text(title).font(TypographyTokens.code)
            Spacer()
            Text(rank.map { inPlace ? "#\($0) in the popup" : "#\($0) in the popup now" } ?? "not offered")
                .font(TypographyTokens.detail)
                .foregroundStyle(inPlace ? ColorTokens.Status.success : ColorTokens.Status.error)
            Button("Remove", systemImage: "xmark", action: remove).labelStyle(.iconOnly).buttonStyle(.borderless)
        }
        .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxs)
        .labField(cornerRadius: 6)
        .contentShape(.rect)
    }
}

/// A text field that is also a drop zone, drawn dashed so it reads as "drop here".
struct ScenarioDropField: View {
    let prompt: String
    @Binding var text: String
    let submit: () -> Void

    var body: some View {
        TextField("", text: $text, prompt: Text(prompt))
            .textFieldStyle(.plain).font(TypographyTokens.code)
            .onSubmit(submit)
            .padding(.horizontal, SpacingTokens.xs).frame(height: 28)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(ColorTokens.Text.tertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }
}

/// A removable pill for a title, a kind or a rule.
struct ScenarioChip: View {
    let text: String
    var tint: Color = ColorTokens.accent
    var mono = true
    let remove: (() -> Void)?

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            Text(text).font(mono ? TypographyTokens.detailMono : TypographyTokens.detail)
            if let remove {
                Button("Remove", systemImage: "xmark", action: remove).labelStyle(.iconOnly).buttonStyle(.borderless).font(TypographyTokens.label)
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, SpacingTokens.xs).frame(height: 22)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

/// Insert text per title: "name" inserts "u.name".
struct ScenarioInsertRows: View {
    @Binding var insertText: [String: String]
    @State private var title = ""
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            ForEach(insertText.keys.sorted(), id: \.self) { key in
                HStack(spacing: SpacingTokens.xs) {
                    Text(key).font(TypographyTokens.code)
                    Image(systemName: "arrow.right").foregroundStyle(ColorTokens.Text.tertiary)
                    TextField("", text: Binding(get: { insertText[key] ?? "" }, set: { insertText[key] = $0 }), prompt: Text("inserted text"))
                        .textFieldStyle(.roundedBorder).font(TypographyTokens.code)
                    Button("Remove", systemImage: "xmark") { insertText[key] = nil }.labelStyle(.iconOnly).buttonStyle(.borderless)
                }
            }
            HStack(spacing: SpacingTokens.xs) {
                TextField("", text: $title, prompt: Text("title, e.g. name")).textFieldStyle(.roundedBorder)
                Image(systemName: "arrow.right").foregroundStyle(ColorTokens.Text.tertiary)
                TextField("", text: $text, prompt: Text("inserts, e.g. u.name")).textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button("Add", systemImage: "plus", action: add).labelStyle(.iconOnly).buttonStyle(.borderless)
                    .disabled(title.isEmpty || text.isEmpty)
            }
            .font(TypographyTokens.code)
        }
    }

    private func add() {
        let key = title.trimmingCharacters(in: .whitespaces), value = text.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !value.isEmpty else { return }
        insertText[key] = value
        title = ""; text = ""
    }
}

/// The kinds a suggestion can have, as EchoSense names them.
enum ScenarioKinds {
    static let all: [String] = ["column", "table", "view", "materializedView", "function", "keyword",
                                "schema", "database", "join", "snippet", "parameter"]

    /// "materializedView" reads "materialized view".
    static func name(_ kind: String) -> String {
        kind.reduce(into: "") { text, character in
            if character.isUppercase { text += " " + character.lowercased() } else { text.append(character) }
        }
    }
}
