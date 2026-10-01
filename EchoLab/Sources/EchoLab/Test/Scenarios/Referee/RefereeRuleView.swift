import EchoSenseScenarios
import SwiftUI

/// "What it needs to do": the rule as numbered groups, each a block in words and the things it
/// names here with their kind and place ("users · table · public"), then what may follow and what
/// must never appear. After the call, each named thing shows whether the popup has it.
struct RefereeRuleView: View {
    let scenario: CompletionScenario
    let resolver: PopupResolver?
    /// Lowercased, unquoted titles the popup offers; nil before EchoSense has run.
    let offered: Set<String>?

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            if !scenario.should.isEmpty {
                Text("The scenario says: \(scenario.should)").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(4).textSelection(.enabled)
            }
            switch scenario.echoSense?.outcome ?? (scenario.popup != nil ? .suggests : nil) {
            case .silent?: box("No popup", "while typing")
            case .nothing?: box("Nothing", "no popup, and nothing when asked by hand (⌘.)")
            case .suggests?:
                if let popup = scenario.popup, let resolver { groups(popup, resolver) } else { oldStyle }
            case nil: box("No rule yet", "Press Change the rule (E) to write one.")
            }
            if let inserts = scenario.echoSense?.insertText, !inserts.isEmpty {
                ForEach(inserts.keys.sorted(), id: \.self) { key in
                    Text("Accepting `\(key)` inserts `\(inserts[key] ?? "")`").font(TypographyTokens.detail)
                }
            }
        }
    }

    @ViewBuilder
    private func groups(_ popup: PopupExpectation, _ resolver: PopupResolver) -> some View {
        ForEach(Array(popup.groups.enumerated()), id: \.offset) { index, group in
            VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                    Text(PopupResolver.ordinal(index)).font(TypographyTokens.headline).foregroundStyle(ColorTokens.accent).frame(width: 34, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(markdown(resolver.describe(group.block, typed: group.typed))).font(TypographyTokens.standard.weight(.medium))
                        Text(group.order.count > 1 ? "In this order: \(group.order.joined(separator: ", "))" : "Any order inside the group")
                            .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
                LabFlowLayout {
                    if let items = resolver.items(group.block, typed: group.typed, order: group.order) {
                        if items.isEmpty { Text("None here, so nothing to show.").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary) }
                        ForEach(Array(items.enumerated()), id: \.offset) { position, item in
                            chip(item, position: group.order.count > 1 ? position + 1 : nil)
                        }
                    } else {
                        Text(group.include.isEmpty ? "Any that fit." : "Any that fit, including:").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                        ForEach(Array(group.include.enumerated()), id: \.offset) { position, name in
                            chip(PopupItem(name: name, kind: kind(of: group.block)), position: group.include.count > 1 ? position + 1 : nil)
                        }
                    }
                }
            }
            .padding(SpacingTokens.xs).frame(maxWidth: .infinity, alignment: .leading).labField(cornerRadius: 8)
        }
        Text(popup.rest == .none ? "THEN NOTHING ELSE" : "THEN ANYTHING ELSE MAY FOLLOW").font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
        if !popup.never.isEmpty {
            LabFlowLayout {
                Text("NEVER").font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Status.error)
                ForEach(Array(popup.never.enumerated()), id: \.offset) { _, block in
                    let names = resolver.items(block)?.map(\.name) ?? []
                    Text(markdown(resolver.describe(block) + (names.isEmpty ? "" : ": " + names.prefix(4).joined(separator: ", "))))
                        .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.error)
                        .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxxs)
                        .background(ColorTokens.Status.error.opacity(0.1), in: .rect(cornerRadius: 6))
                }
            }
        }
    }

    /// A scenario that still lists titles instead of blocks.
    private var oldStyle: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Label("Listed titles, no kinds. Change the rule (E) to write it with blocks.", systemImage: "exclamationmark.triangle")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.warning)
            LabFlowLayout {
                ForEach(Array((scenario.echoSense?.items ?? []).enumerated()), id: \.offset) { position, name in
                    Text("\(position + 1) \(name)").font(TypographyTokens.code).padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxxs).labField(cornerRadius: 6)
                }
            }
            if let excludes = scenario.echoSense?.excludes, !excludes.isEmpty {
                Text("Never: \(excludes.joined(separator: ", "))").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.error)
            }
        }
    }

    private func chip(_ item: PopupItem, position: Int?) -> some View {
        let status: Bool? = offered.map { $0.contains(item.name.lowercased()) }
        return HStack(spacing: SpacingTokens.xxs) {
            if let position { Text("\(position)").font(TypographyTokens.detail.weight(.bold)).foregroundStyle(ColorTokens.accent) }
            Text(item.name).font(TypographyTokens.code)
            ScenarioKindPill(kind: item.kind)
            if !item.parent.isEmpty { Text(item.parent).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary) }
            if let status { Image(systemName: status ? "checkmark" : "xmark").foregroundStyle(status ? ColorTokens.Status.success : ColorTokens.Status.error) }
        }
        .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxxs)
        .background(status.map { ($0 ? ColorTokens.Status.success : ColorTokens.Status.error).opacity(0.1) } ?? ColorTokens.Surface.rest, in: .rect(cornerRadius: 6))
    }

    private func box(_ title: String, _ detail: String) -> some View {
        VStack(spacing: SpacingTokens.xxs) {
            Text(title.uppercased()).font(TypographyTokens.headline)
            Text(detail).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity).padding(SpacingTokens.md)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ColorTokens.Text.tertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }

    private func kind(of block: PopupBlock) -> String {
        switch block.family { case .functions: "function"; case .keywords: "keyword"; case .snippets: "snippet"; case .parameters: "parameter"; default: "table" }
    }

    private func markdown(_ text: String) -> AttributedString { ScenarioChecksCard.markdown(text) }
}
