import SwiftUI

/// Object details and foreign-key records as inspector cards (plan I2): the record's card, then a
/// card for each related record, one gutter apart.
struct InspectorPanelView: View {
    let content: DatabaseObjectInspectorContent
    let depth: Int
    var systemImage = "cube"

    @Environment(EnvironmentState.self) private var environmentState
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            InspectorSection(title: content.title, subtitle: content.subtitle, systemImage: depth == 0 ? systemImage : "arrow.turn.down.right") {
                if let query = resolvedLookupQuery {
                    Button {
                        environmentState.openQueryTab(presetQuery: query, autoExecute: true)
                    } label: {
                        Label("Open in Query Tab", systemImage: "arrow.up.right.square")
                    }
                    .help("Open \(content.title.isEmpty ? "record" : content.title) in a new query tab")
                }
            } content: {
                if let errorMessage = content.errorMessage {
                    Label {
                        Text(errorMessage).font(TypographyTokens.detail)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(ColorTokens.Status.warning)
                    }
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .padding(.bottom, SpacingTokens.xxs)
                }
                if let sql = content.sqlText, !sql.isEmpty {
                    InspectorSQLBlock(sql: sql) {
                        environmentState.openQueryTab(presetQuery: sql)
                    }
                    .padding(.bottom, SpacingTokens.xxs)
                }
                ForEach(Array(content.fields.enumerated()), id: \.element.id) { index, field in
                    InspectorSectionRow(label: field.label, value: field.value, isLast: index == content.fields.count - 1)
                }
            }

            ForEach(Array(content.related.enumerated()), id: \.offset) { _, related in
                InspectorPanelView(content: related, depth: depth + 1)
            }
        }
    }

    private var resolvedLookupQuery: String? {
        guard let raw = content.lookupQuerySQL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return raw
    }
}
