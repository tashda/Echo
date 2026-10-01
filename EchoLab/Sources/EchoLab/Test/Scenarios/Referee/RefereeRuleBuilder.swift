import EchoSenseScenarios
import SwiftUI

/// Builds a scenario's rule from blocks: what happens at the caret, then groups in order (drag or
/// arrows), each narrowed to what is typed, to tables not yet in the query or to key columns, with a
/// set order or names it must include; then whether anything else may follow, and what must never
/// appear. Works on a draft the page saves.
struct RefereeRuleBuilder: View {
    @Binding var scenario: CompletionScenario
    let resolver: PopupResolver?

    private enum PaletteTarget { case group, never }
    @State private var palette: PaletteTarget?
    @State private var newNames: [Int: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Picker("At the caret", selection: outcome) {
                Text("The popup shows…").tag(EchoSenseExpectation.Outcome.suggests)
                Text("No popup while typing").tag(EchoSenseExpectation.Outcome.silent)
                Text("Nothing, even by hand").tag(EchoSenseExpectation.Outcome.nothing)
            }
            .pickerStyle(.segmented)
            if outcome.wrappedValue == .suggests {
                Text("Groups come in order: everything in the 1st group before anything in the 2nd. Drag a group, or use the arrows.")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                ForEach(Array(popup.groups.enumerated()), id: \.offset) { index, group in groupEditor(index, group) }
                HStack(spacing: SpacingTokens.xs) {
                    Button("Add a group", systemImage: "plus") { palette = palette == .group ? nil : .group }
                        .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, isOn: palette == .group))
                    Picker("Then", selection: popupBinding(\.rest)) {
                        Text("Then anything else may follow").tag(PopupExpectation.Rest.any)
                        Text("Then nothing else").tag(PopupExpectation.Rest.none)
                    }
                    .fixedSize()
                }
            }
            LabFlowLayout {
                Text("Never").font(TypographyTokens.standard.weight(.semibold))
                ForEach(Array(popup.never.enumerated()), id: \.offset) { index, block in
                    ScenarioChip(text: resolver?.describe(block).replacingOccurrences(of: "`", with: "") ?? block.family.rawValue, tint: ColorTokens.Status.error, mono: false) {
                        edit { $0.never.remove(at: index) }
                    }
                }
                Button("Never…", systemImage: "plus") { palette = palette == .never ? nil : .never }
                    .buttonStyle(LabPillButtonStyle(tint: ColorTokens.Status.error, isOn: palette == .never))
            }
            if palette != nil { paletteView }
            if outcome.wrappedValue == .suggests {
                Text("Accepting inserts").font(TypographyTokens.standard.weight(.semibold))
                ScenarioInsertRows(insertText: Binding(get: { scenario.echoSense?.insertText ?? [:] }, set: { scenario.echoSense?.insertText = $0 }))
            }
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ColorTokens.accent, lineWidth: 1.5))
    }

    // MARK: Groups

    private func groupEditor(_ index: Int, _ group: PopupGroup) -> some View {
        let items = resolver?.items(group.block, typed: group.typed)
        let context = resolver?.context
        return VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Image(systemName: "line.3.horizontal").foregroundStyle(ColorTokens.Text.tertiary).help("Drag to reorder")
                Text(PopupResolver.ordinal(index)).font(TypographyTokens.headline).foregroundStyle(ColorTokens.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(ScenarioChecksCard.markdown(resolver?.describe(group.block, typed: group.typed) ?? "")).font(TypographyTokens.standard.weight(.medium))
                    Text(items.map { "\($0.count) here: \($0.prefix(6).map(\.name).joined(separator: ", "))" } ?? "Matched by kind").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                }
                Spacer()
                Button("Earlier", systemImage: "arrow.up") { move(index, to: index - 1) }.labelStyle(.iconOnly).buttonStyle(.borderless).disabled(index == 0)
                Button("Later", systemImage: "arrow.down") { move(index, to: index + 1) }.labelStyle(.iconOnly).buttonStyle(.borderless).disabled(index == popup.groups.count - 1)
                Button("Remove", systemImage: "xmark") { edit { $0.groups.remove(at: index) } }.labelStyle(.iconOnly).buttonStyle(.borderless)
            }
            LabFlowLayout {
                if let typed = context?.typed, !typed.isEmpty {
                    Toggle("Starting with “\(typed)”", isOn: groupBinding(index, \.typed)).toggleStyle(.checkbox)
                }
                if group.block.family == .objects, group.block.place != .inQuery, !(context?.tables.isEmpty ?? true) {
                    Toggle("Not yet in the query", isOn: Binding(get: { group.block.notInQuery }, set: { value in edit { $0.groups[index].block.notInQuery = value } })).toggleStyle(.checkbox)
                }
                if group.block.family == .columns {
                    Toggle("Key columns only", isOn: Binding(get: { group.block.keysOnly }, set: { value in edit { $0.groups[index].block.keysOnly = value } })).toggleStyle(.checkbox)
                }
                if let items, items.count > 1 {
                    Toggle("In a set order", isOn: Binding(get: { !group.order.isEmpty }, set: { on in edit { $0.groups[index].order = on ? items.map(\.name) : [] } })).toggleStyle(.checkbox)
                }
            }
            .font(TypographyTokens.detail)
            if !group.order.isEmpty { orderEditor(index, group.order) }
            if items == nil { includeEditor(index, group.include) }
        }
        .padding(SpacingTokens.xs).labField(cornerRadius: 8)
        .draggable("refgroup:\(index)")
        .dropDestination(for: String.self) { texts, _ in
            if let text = texts.first, text.hasPrefix("refgroup:"), let from = Int(text.dropFirst(9)) { move(from, to: index) }
        }
    }

    private func orderEditor(_ index: Int, _ order: [String]) -> some View {
        LabFlowLayout {
            ForEach(Array(order.enumerated()), id: \.offset) { position, name in
                HStack(spacing: SpacingTokens.xxs) {
                    Text("\(position + 1)").font(TypographyTokens.detail.weight(.bold)).foregroundStyle(ColorTokens.accent)
                    Text(name).font(TypographyTokens.code)
                    Button("Earlier", systemImage: "arrow.left") { edit { $0.groups[index].order.swapAt(position, position - 1) } }
                        .labelStyle(.iconOnly).buttonStyle(.borderless).disabled(position == 0)
                }
                .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxxs).labField(cornerRadius: 6)
                .draggable("reforder:\(index):\(position)")
                .dropDestination(for: String.self) { texts, _ in
                    let parts = texts.first?.split(separator: ":") ?? []
                    guard parts.count == 3, parts[0] == "reforder", Int(parts[1]) == index, let from = Int(parts[2]), from != position else { return }
                    edit { value in
                        let name = value.groups[index].order.remove(at: from)
                        value.groups[index].order.insert(name, at: position)
                    }
                }
            }
        }
    }

    private func includeEditor(_ index: Int, _ include: [String]) -> some View {
        LabFlowLayout {
            Text("Must include, in this order:").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            ForEach(Array(include.enumerated()), id: \.offset) { position, name in
                ScenarioChip(text: "\(position + 1) \(name)") { edit { $0.groups[index].include.remove(at: position) } }
            }
            TextField("", text: Binding(get: { newNames[index] ?? "" }, set: { newNames[index] = $0 }), prompt: Text("e.g. COALESCE"))
                .textFieldStyle(.roundedBorder).frame(width: 140)
                .onSubmit {
                    let name = (newNames[index] ?? "").trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { edit { $0.groups[index].include.append(name) } }
                    newNames[index] = ""
                }
        }
    }

    // MARK: Palette

    private var paletteView: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(palette == .never ? "Never offer…" : "Add a group: pick a block").font(TypographyTokens.standard.weight(.semibold))
            LabFlowLayout(spacing: SpacingTokens.xs) {
                ForEach(RefereeBlockCatalog.families) { family in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        HStack { ScenarioKindPill(kind: family.kind); Text(family.title).font(TypographyTokens.standard.weight(.medium)) }
                        ForEach(family.entries) { entry in
                            let available = resolver.map { entry.isAvailable($0.context) } ?? false
                            let count = available ? resolver?.items(entry.block)?.count : nil
                            Button { pick(entry.block) } label: {
                                Text(entry.label + (count.map { " (\($0))" } ?? "")).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(LabPillButtonStyle())
                            .disabled(!available)
                            .help(available ? "" : "Not in this query")
                        }
                    }
                    .padding(SpacingTokens.xs).frame(width: 280, alignment: .topLeading).labField(cornerRadius: 8)
                }
            }
            Text("The number is how many things the block names in this query.").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
        }
    }

    private func pick(_ block: PopupBlock) {
        if palette == .never { edit { $0.never.append(block) } } else { edit { $0.groups.append(PopupGroup(block)) } }
        palette = nil
    }

    // MARK: Editing

    private var popup: PopupExpectation { scenario.popup ?? PopupExpectation() }

    private var outcome: Binding<EchoSenseExpectation.Outcome> {
        Binding(get: { scenario.echoSense?.outcome ?? .suggests }, set: { value in
            var expectation = scenario.echoSense ?? EchoSenseExpectation(outcome: value)
            expectation.outcome = value
            scenario.echoSense = expectation
            if value == .suggests, scenario.popup == nil { scenario.popup = PopupExpectation() }
        })
    }

    private func popupBinding<T>(_ keyPath: WritableKeyPath<PopupExpectation, T>) -> Binding<T> {
        Binding(get: { popup[keyPath: keyPath] }, set: { value in edit { $0[keyPath: keyPath] = value } })
    }

    private func groupBinding<T>(_ index: Int, _ keyPath: WritableKeyPath<PopupGroup, T>) -> Binding<T> {
        Binding(get: { popup.groups[index][keyPath: keyPath] }, set: { value in edit { $0.groups[index][keyPath: keyPath] = value } })
    }

    private func edit(_ change: (inout PopupExpectation) -> Void) {
        var value = popup
        change(&value)
        scenario.popup = value
        if scenario.echoSense == nil { scenario.echoSense = EchoSenseExpectation(outcome: .suggests) }
    }

    private func move(_ from: Int, to: Int) {
        guard from != to, popup.groups.indices.contains(from), popup.groups.indices.contains(to) else { return }
        edit { value in
            let group = value.groups.remove(at: from)
            value.groups.insert(group, at: to)
        }
    }
}
