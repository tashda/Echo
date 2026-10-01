import SwiftUI

extension EnvironmentValues {
    /// Opens a round page inside the current area (set by the area page).
    @Entry var labOpenRound: (String) -> Void = { _ in }
}

/// A titled group on an As built page: a header and a quiet card of rows.
struct AsBuiltSection<Content: View>: View {
    let title: String
    var caption: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(TypographyTokens.headline)
                if let caption {
                    Text(caption).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.Surface.rest, in: .rect(cornerRadius: 12, style: .continuous))
        }
    }
}

/// One row inside a section, with a hairline above every row but the first.
struct AsBuiltRow<Content: View>: View {
    let isFirst: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isFirst { Divider() }
            content
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.vertical, SpacingTokens.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct AsBuiltBehaviourList: View {
    let items: [AsBuiltPage.Behaviour]

    var body: some View {
        AsBuiltSection(title: "How it behaves") {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                AsBuiltRow(isFirst: index == 0) {
                    HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.md) {
                        Text(item.trigger).font(TypographyTokens.standard.weight(.medium)).frame(width: 200, alignment: .leading)
                        Text(item.result).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }
        }
    }
}

struct AsBuiltMotionList: View {
    let items: [AsBuiltPage.Motion]

    var body: some View {
        AsBuiltSection(title: "How it moves", caption: "Use Replay above the stage to watch it again. Reduce Motion turns every move into a 0.18s fade.") {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                AsBuiltRow(isFirst: index == 0) {
                    HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.md) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name).font(TypographyTokens.standard.weight(.medium))
                            if let note = item.note {
                                Text(note).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                            }
                        }
                        .frame(width: 200, alignment: .leading)
                        Text(item.curve).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                        Spacer()
                        Text(item.duration).font(TypographyTokens.standard.monospacedDigit())
                    }
                }
            }
        }
    }
}

struct AsBuiltMeasurementList: View {
    let items: [AsBuiltPage.Measurement]

    var body: some View {
        AsBuiltSection(title: "Measurements and tokens") {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                AsBuiltRow(isFirst: index == 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.md) {
                            Text(item.label).font(TypographyTokens.standard).frame(width: 200, alignment: .leading)
                            Text(item.value).font(TypographyTokens.standard.weight(.medium).monospacedDigit())
                            Spacer()
                            if let token = item.token {
                                Text(token).font(.system(size: 11, design: .monospaced)).foregroundStyle(ColorTokens.Text.tertiary)
                            }
                        }
                        if let check = item.check {
                            Label(check, systemImage: "exclamationmark.triangle")
                                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.warning)
                        }
                    }
                }
            }
        }
    }
}

struct AsBuiltRuleList: View {
    let items: [AsBuiltPage.Rule]
    @Environment(\.labOpenRound) private var openRound

    var body: some View {
        AsBuiltSection(title: "Why it looks this way") {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                AsBuiltRow(isFirst: index == 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.text).font(TypographyTokens.standard.weight(.medium))
                        Text(item.why).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                        HStack(spacing: SpacingTokens.xs) {
                            ForEach(item.rounds, id: \.self) { id in
                                if let page = LabRegistry.page(id: id) {
                                    Button(page.title) { openRound(id) }
                                        .buttonStyle(.link).font(TypographyTokens.detail)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct AsBuiltCodeList: View {
    let paths: [String]

    var body: some View {
        AsBuiltSection(title: "In the code") {
            ForEach(Array(paths.enumerated()), id: \.offset) { index, path in
                AsBuiltRow(isFirst: index == 0) {
                    Text(path).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                }
            }
        }
    }
}
