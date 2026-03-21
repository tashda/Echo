import SwiftUI
import EchoSense

struct AutoCompletionDetailView: View {
    let suggestion: SQLAutoCompletionSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            nameSection
            if hasMetadata {
                Divider()
                metadataRows
            }
        }
        .padding(.horizontal, SpacingTokens.xs2)
        .padding(.vertical, SpacingTokens.xs2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(detailBackground)
        .overlay(detailOverlay)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            HStack(spacing: SpacingTokens.xxs2) {
                Image(systemName: suggestion.kind.iconSystemName)
                    .font(TypographyTokens.standard.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.secondary)
                Text(suggestion.title)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(2)
            }
            Text(suggestion.displayKindTitle)
                .font(TypographyTokens.caption2)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    private var hasMetadata: Bool {
        let hasSchema = suggestion.origin?.schema?.isEmpty == false
        let hasDatabase = suggestion.origin?.database?.isEmpty == false
        let hasDataType = suggestion.kind == .column && suggestion.dataType?.isEmpty == false
        let hasTable = suggestion.kind == .column && suggestion.origin?.object?.isEmpty == false
        return hasSchema || hasDatabase || hasDataType || hasTable
    }

    @ViewBuilder
    private var metadataRows: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            if let schema = suggestion.origin?.schema, !schema.isEmpty {
                schemaRow(schema)
            }
            if let database = suggestion.origin?.database, !database.isEmpty {
                metadataRow(systemIcon: "externaldrive", value: database)
            }
            if suggestion.kind == .column, let dataType = suggestion.dataType, !dataType.isEmpty {
                metadataRow(systemIcon: "chevron.left.forwardslash.chevron.right", value: dataType)
            }
            if suggestion.kind == .column, let table = suggestion.origin?.object, !table.isEmpty {
                metadataRow(systemIcon: "tablecells", value: table)
            }
        }
    }

    private func schemaRow(_ schema: String) -> some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Image("schema")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text(schema)
                .font(TypographyTokens.caption2)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    private func metadataRow(systemIcon: String, value: String) -> some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Image(systemName: systemIcon)
                .font(TypographyTokens.caption2)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .frame(width: 13)
            Text(value)
                .font(TypographyTokens.caption2)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

#if os(macOS)
    private var detailBackground: some View { Color.clear }
    private var detailOverlay: some View { EmptyView() }
#else
    private var detailBackground: some View { RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium, style: .continuous).fill(Color.white.opacity(0.95)) }
    private var detailOverlay: some View { RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium, style: .continuous).stroke(Color.black.opacity(0.08), lineWidth: 1) }
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
