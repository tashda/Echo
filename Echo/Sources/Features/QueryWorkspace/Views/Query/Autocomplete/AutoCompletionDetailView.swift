import SwiftUI
import EchoSense

struct AutoCompletionDetailView: View {
    let suggestion: SQLAutoCompletionSuggestion

    private enum Layout {
        static let cornerRadius: CGFloat = 8
        static let columnSpacing: CGFloat = SpacingTokens.xxxs
        static let columnBadgePadding = EdgeInsets(top: 2, leading: 5, bottom: 2, trailing: 5)
        static let maxColumnListHeight: CGFloat = 180
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            header
            contentBody
        }
        .padding(.horizontal, SpacingTokens.xs2)
        .padding(.vertical, SpacingTokens.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(detailBackground)
        .overlay(detailOverlay)
    }

    @ViewBuilder
    private var contentBody: some View {
        switch suggestion.kind {
        case .table, .view, .materializedView: tableDetail
        case .column: columnDetail
        default: genericDetail
        }
    }

    private var header: some View {
        Text(suggestion.displayKindTitle)
            .font(TypographyTokens.detail.weight(.semibold))
            .foregroundStyle(Color.secondary)
            .textCase(.uppercase)
    }

    @ViewBuilder
    private var tableDetail: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let schema = suggestion.origin?.schema, let name = suggestion.origin?.object {
                HStack(spacing: 6) {
                    schemaChip(schema)
                    Text(name).font(TypographyTokens.standard.weight(.medium)).foregroundStyle(Color.primary)
                }
            }
            if let columns = suggestion.tableColumns, !columns.isEmpty {
                ColumnListView(columns: columns)
            } else {
                Text("No columns available").font(TypographyTokens.detail).foregroundStyle(Color.secondary)
            }
        }
    }

    @ViewBuilder
    private var columnDetail: some View {
        Text(suggestion.dataType ?? "Column")
            .font(TypographyTokens.detail)
            .italic(suggestion.dataType != nil)
            .foregroundStyle(Color.secondary)
    }

    @ViewBuilder
    private var genericDetail: some View {
        if let objectPath = suggestion.displayObjectPath {
            Text(objectPath).font(TypographyTokens.standard.weight(.medium)).foregroundStyle(Color.primary)
        }
    }

    private func schemaChip(_ schema: String) -> some View {
        HStack(spacing: 4) {
            Image("schema").resizable().renderingMode(.template).scaledToFit().frame(width: 10, height: 10)
            Text(schema).font(TypographyTokens.detail.weight(.medium))
        }
        .foregroundStyle(Color.secondary)
        .padding(.horizontal, SpacingTokens.xxs2).padding(.vertical, SpacingTokens.xxxs)
        .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.06)))
    }

    private struct ColumnListView: View {
        let columns: [SQLAutoCompletionSuggestion.TableColumn]

        var body: some View {
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: Layout.columnSpacing) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                        HStack(spacing: SpacingTokens.xxs2) {
                            Text(column.name).font(TypographyTokens.caption2).foregroundStyle(Color.primary)
                            Spacer(minLength: SpacingTokens.xs2)
                            Text(EchoFormatters.abbreviatedSQLType(column.dataType))
                                .font(TypographyTokens.label.weight(.medium))
                                .foregroundStyle(Color.secondary).padding(Layout.columnBadgePadding)
                                .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.06)))
                        }
                    }
                }
            }
            .frame(maxHeight: Layout.maxColumnListHeight)
        }
    }

#if os(macOS)
    private var detailBackground: some View { Color.clear }
    private var detailOverlay: some View { EmptyView() }
#else
    private var detailBackground: some View { RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous).fill(Color.white.opacity(0.95)) }
    private var detailOverlay: some View { RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous).stroke(Color.black.opacity(0.08), lineWidth: 1) }
#endif
}

#if os(macOS)
struct GlassBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var emphasized: Bool = false
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material; view.blendingMode = blendingMode; view.state = .active; view.isEmphasized = emphasized
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material; nsView.blendingMode = blendingMode; nsView.isEmphasized = emphasized; nsView.state = .active
    }
}
#endif
