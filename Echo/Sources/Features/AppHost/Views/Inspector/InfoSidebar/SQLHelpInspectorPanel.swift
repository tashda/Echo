import SwiftUI
import EchoSense

struct SQLHelpInspectorPanel: View {
    let content: SQLHelpInspectorContent
    @Environment(EnvironmentState.self) private var environmentState

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            header

            if let syntax = content.syntax, !syntax.isEmpty {
                InspectorSQLBlock(sql: syntax) {
                    environmentState.openQueryTab(presetQuery: syntax)
                }
            }

            if let example = content.example, !example.isEmpty {
                exampleSection(example)
            }

            if !content.sections.isEmpty {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    ForEach(content.sections) { section in
                        valueSection(title: section.title, value: section.value)
                    }
                }
            }

            if !content.notes.isEmpty {
                notesSection
            }

            if !content.relatedTopics.isEmpty {
                relatedSection
            }
        }
        .padding(.top, SpacingTokens.xxs)
        .padding(.bottom, SpacingTokens.xxs)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Text(content.title)
                    .font(TypographyTokens.title3.weight(.semibold))
                Text(content.category)
                    .font(TypographyTokens.caption.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .padding(.horizontal, SpacingTokens.xs2)
                    .padding(.vertical, SpacingTokens.xxxs)
                    .background(
                        Capsule(style: .continuous)
                            .fill(ColorTokens.Background.secondary)
                    )
            }

            Text(content.summary)
                .font(TypographyTokens.subheadline)
                .foregroundStyle(ColorTokens.Text.secondary)

            if !content.matchedText.isEmpty,
               content.matchedText.caseInsensitiveCompare(content.title) != .orderedSame {
                Text("Matched selection: \(content.matchedText)")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
    }

    private func exampleSection(_ example: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text("Example")
                .font(TypographyTokens.caption2)
                .foregroundStyle(ColorTokens.Text.secondary)

            InspectorSQLBlock(sql: example) {
                environmentState.openQueryTab(presetQuery: example)
            }
        }
    }

    private func valueSection(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            Text(title.uppercased())
                .font(TypographyTokens.caption2)
                .foregroundStyle(ColorTokens.Text.secondary)
            Text(value)
                .font(TypographyTokens.callout)
                .foregroundStyle(ColorTokens.Text.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, SpacingTokens.xs)
                .padding(.horizontal, SpacingTokens.xs2)
                .background(
                    RoundedRectangle(cornerRadius: SpacingTokens.xs2, style: .continuous)
                        .fill(ColorTokens.Background.secondary)
                )
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Notes")
                .font(TypographyTokens.caption.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)

            ForEach(Array(content.notes.enumerated()), id: \.offset) { _, note in
                Label {
                    Text(note)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.primary)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Related")
                .font(TypographyTokens.caption.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: SpacingTokens.xs)], alignment: .leading, spacing: SpacingTokens.xs) {
                ForEach(content.relatedTopics, id: \.self) { topic in
                    Button(topic) {
                        if let related = SQLHelpInspectorContentProvider().content(for: topic, databaseType: .mysql)
                            ?? SQLHelpInspectorContentProvider().content(for: topic, databaseType: .postgresql)
                            ?? SQLHelpInspectorContentProvider().content(for: topic, databaseType: .microsoftSQL)
                            ?? SQLHelpInspectorContentProvider().content(for: topic, databaseType: .sqlite) {
                            environmentState.dataInspectorContent = .sqlHelp(related)
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(TypographyTokens.detail.weight(.medium))
                    .foregroundStyle(ColorTokens.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SpacingTokens.xs2)
                    .padding(.vertical, SpacingTokens.xs)
                    .background(
                        RoundedRectangle(cornerRadius: SpacingTokens.xs2, style: .continuous)
                            .fill(ColorTokens.accent.opacity(0.08))
                    )
                }
            }
        }
    }
}
