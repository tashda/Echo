import SwiftUI

struct InspectorPanelView: View {
    let content: DatabaseObjectInspectorContent
    let depth: Int
    @Environment(EnvironmentState.self) private var environmentState

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md1) {
            HStack(alignment: .top, spacing: SpacingTokens.sm) {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text(content.title)
                        .font(TypographyTokens.title3.weight(.semibold))
                    if let subtitle = content.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(TypographyTokens.subheadline)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
                Spacer(minLength: SpacingTokens.xs)
                if let query = resolvedLookupQuery {
                    let targetTitle = content.title.isEmpty ? "record" : content.title
                    Button {
                        openForeignRecord(with: query)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(TypographyTokens.standard.weight(.semibold))
                            .foregroundStyle(ColorTokens.accent)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous)
                                    .fill(ColorTokens.accent.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Open \(targetTitle) in a new query tab")
                }
            }

            if let errorMessage = content.errorMessage {
                Label {
                    Text(errorMessage)
                        .font(TypographyTokens.detail)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(ColorTokens.Status.warning)
                }
                .foregroundStyle(ColorTokens.Text.secondary)
            }

            if !content.fields.isEmpty {
                VStack(alignment: .leading, spacing: SpacingTokens.sm2) {
                    ForEach(content.fields) { field in
                        InspectorFieldRow(field: field)
                    }
                }
            }

            if !content.related.isEmpty {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Text("Related Records")
                        .font(TypographyTokens.caption.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                ForEach(Array(content.related.enumerated()), id: \.offset) { _, related in
                    RelatedInspectorSection(content: related, depth: depth + 1)
                }
            }
        }
        .padding(.top, depth == 0 ? SpacingTokens.xxs : 0)
        .padding(.bottom, SpacingTokens.xxs)
    }

    private var resolvedLookupQuery: String? {
        guard let raw = content.lookupQuerySQL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return raw
    }

    private func openForeignRecord(with sql: String) {
        environmentState.openQueryTab(presetQuery: sql, autoExecute: true)
    }
}
