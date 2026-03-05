import SwiftUI

struct InspectorPanelView: View {
    let content: ForeignKeyInspectorContent
    let depth: Int
    @EnvironmentObject private var environmentState: EnvironmentState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(content.title)
                        .font(.system(.title3, design: .default).weight(.semibold))
                    if let subtitle = content.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if let query = resolvedLookupQuery {
                    let targetTitle = content.title.isEmpty ? "record" : content.title
                    Button {
                        openForeignRecord(with: query)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(TypographyTokens.standard.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Open \(targetTitle) in a new query tab")
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(content.fields) { field in
                    InspectorFieldRow(field: field)
                }
            }

            if !content.related.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Related Records")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
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
