import EchoSense
import SwiftUI

/// What a suggestion or an expected item is, in words, with the symbol EchoSense gives the kind and
/// the colour the Explorer tree uses for it: table, view, column, function, keyword, schema, ...
struct ScenarioKindPill: View {
    let kind: String

    var body: some View {
        Label(Self.title(kind), systemImage: SQLAutoCompletionKind(rawValue: kind)?.iconSystemName ?? (kind == "procedure" ? "gearshape" : "questionmark"))
            .font(TypographyTokens.detail.weight(.medium))
            .foregroundStyle(Self.tint(kind))
            .padding(.horizontal, SpacingTokens.xxs2).frame(height: 20)
            .background(Self.tint(kind).opacity(0.14), in: .rect(cornerRadius: 5))
            .fixedSize()
    }

    static func title(_ kind: String) -> String {
        switch kind {
        case "materializedView": "materialized view"
        case "join": "table, joins on a key"
        default: kind
        }
    }

    static func tint(_ kind: String) -> Color {
        switch kind {
        case "table", "join": ColorTokens.Explorer.tables
        case "view": ColorTokens.Explorer.views
        case "materializedView": ColorTokens.Explorer.materializedViews
        case "column": ColorTokens.Explorer.extensions
        case "function": ColorTokens.Explorer.functions
        case "procedure": ColorTokens.Explorer.procedures
        case "schema": ColorTokens.Explorer.databaseFolder
        case "database": ColorTokens.Explorer.databaseInstance
        case "snippet", "parameter": ColorTokens.Explorer.sequences
        default: ColorTokens.Text.secondary
        }
    }
}
