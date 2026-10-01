import EchoSenseScenarios
import SwiftUI

/// A shared rule, edited as a draft: its name and meaning, titles and kinds it forbids, and the order
/// kinds must rank in (drag to reorder). Save changes every scenario that follows it, in every area.
struct ScenarioRuleEditor: View {
    let store: ScenarioStore
    @State private var draft: ScenarioRule
    @State private var newTitle = ""
    @State private var confirmsDelete = false
    @Environment(\.dismiss) private var dismiss

    init(rule: ScenarioRule, store: ScenarioStore) {
        self.store = store
        _draft = State(initialValue: rule)
    }

    var body: some View {
        let followers = store.scenarios(following: draft.id)
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                LabTag(text: draft.id)
                Text("Followed by \(followers.count) scenario\(followers.count == 1 ? "" : "s") in \(Set(followers.map(\.group)).count) areas")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
            TextField("", text: $draft.title, prompt: Text("Rule name, e.g. Columns before keywords")).textFieldStyle(.roundedBorder)
                .font(TypographyTokens.headline)
            TextField("", text: $draft.should, prompt: Text("What it means, in your words"), axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(2...4)
            section("Never offers these titles") {
                LabFlowLayout {
                    ForEach(draft.excludes, id: \.self) { title in
                        ScenarioChip(text: title, tint: ColorTokens.Status.error) { draft.excludes.removeAll { $0 == title } }
                    }
                }
                ScenarioDropField(prompt: "Add a title, or drop one here", text: $newTitle) {
                    let title = newTitle.trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty, !draft.excludes.contains(title) { draft.excludes.append(title) }
                    newTitle = ""
                }
                .dropDestination(for: String.self) { texts, _ in
                    if let title = ScenarioDragItem.first(in: texts)?.title, !draft.excludes.contains(title) { draft.excludes.append(title) }
                }
            }
            section("Never offers these kinds") {
                LabFlowLayout {
                    ForEach(ScenarioKinds.all, id: \.self) { kind in
                        Button(ScenarioKinds.name(kind)) { toggle(kind, in: \.excludedKinds) }
                            .buttonStyle(LabPillButtonStyle(tint: ColorTokens.Status.error, isOn: draft.excludedKinds.contains(kind)))
                    }
                }
            }
            section("Kinds rank in this order") {
                Text("Every suggestion of a kind higher in this list comes before any of a kind lower down. Drag to reorder.")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                ForEach(Array(draft.kindOrder.enumerated()), id: \.element) { index, kind in
                    HStack(spacing: SpacingTokens.xs) {
                        Image(systemName: "line.3.horizontal").foregroundStyle(ColorTokens.Text.tertiary)
                        Text("\(index + 1)").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.secondary)
                        Text(ScenarioKinds.name(kind)).font(TypographyTokens.standard)
                        Spacer()
                        Button("Remove", systemImage: "xmark") { draft.kindOrder.remove(at: index) }.labelStyle(.iconOnly).buttonStyle(.borderless)
                    }
                    .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxs).labField(cornerRadius: 6)
                    .draggable(ScenarioDragItem.kind(kind).text)
                    .dropDestination(for: String.self) { texts, _ in moveKind(texts, before: index) }
                }
                Menu("Add a kind", systemImage: "plus") {
                    ForEach(ScenarioKinds.all.filter { !draft.kindOrder.contains($0) }, id: \.self) { kind in
                        Button(ScenarioKinds.name(kind)) { draft.kindOrder.append(kind) }
                    }
                }
                .fixedSize()
            }
            Spacer(minLength: 0)
            HStack {
                Button("Delete rule", role: .destructive) { confirmsDelete = true }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { store.updateRule(draft); dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(SpacingTokens.lg)
        .frame(width: 520)
        .frame(minHeight: 560)
        .confirmationDialog("Delete \(draft.title)?", isPresented: $confirmsDelete) {
            Button("Delete and stop following it everywhere", role: .destructive) { store.deleteRule(draft.id); dismiss() }
        } message: {
            Text("\(followers.count) scenarios follow this rule. They keep their own checks.")
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text(title).font(TypographyTokens.standard.weight(.semibold))
            content()
        }
    }

    private func toggle(_ kind: String, in keyPath: WritableKeyPath<ScenarioRule, [String]>) {
        if draft[keyPath: keyPath].contains(kind) { draft[keyPath: keyPath].removeAll { $0 == kind } } else { draft[keyPath: keyPath].append(kind) }
    }

    private func moveKind(_ texts: [String], before index: Int) {
        guard case .kind(let kind)? = ScenarioDragItem.first(in: texts), let from = draft.kindOrder.firstIndex(of: kind), from != index else { return }
        draft.kindOrder.remove(at: from)
        draft.kindOrder.insert(kind, at: min(from < index ? index - 1 : index, draft.kindOrder.count))
    }
}
