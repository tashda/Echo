import EchoSense
import SwiftUI

/// Type SQL, move the caret, and see exactly what EchoSense would offer and why.
struct EchoSenseTestPage: View {
    @State private var model = EchoSenseTestModel()

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                controls
                Divider()
                LabCaretTextView(text: $model.text, caret: $model.caret)
            }
            .frame(minWidth: 380)
            results.frame(minWidth: 420)
        }
    }

    private var controls: some View {
        Form {
            Picker("Dialect", selection: $model.databaseType) {
                Text("PostgreSQL").tag(EchoSenseDatabaseType.postgresql)
                Text("SQL Server").tag(EchoSenseDatabaseType.microsoftSQL)
                Text("MySQL").tag(EchoSenseDatabaseType.mysql)
                Text("SQLite").tag(EchoSenseDatabaseType.sqlite)
            }
            Picker("Aggressiveness", selection: $model.aggressiveness) {
                ForEach(SQLCompletionAggressiveness.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            Toggle("Include system schemas", isOn: $model.includeSystemSchemas)
            Toggle("Qualify table insertions", isOn: $model.qualifyTables)
            Toggle("Alias shortcuts", isOn: $model.aliasShortcuts)
            Toggle("Manual trigger (⌘.)", isOn: $model.manualTrigger)
            LabeledContent("Schema") {
                HStack {
                    Text(model.liveSource ?? "Sample: shop (sales, hr)")
                        .foregroundStyle(ColorTokens.Text.secondary)
                    if LabLiveSession.shared.connection?.structure != nil {
                        Button("Use live schema") { model.useLiveSchema() }
                    }
                    if model.liveStructure != nil {
                        Button("Use sample") { model.liveStructure = nil; model.liveSource = nil }
                    }
                    Button("Reset SQL") { model.reset() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 290)
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 0) {
            summary.padding(SpacingTokens.md)
            Divider()
            if let response = model.response, !response.suggestions.isEmpty {
                List(Array(response.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    EchoSenseSuggestionRow(rank: index + 1, suggestion: suggestion, token: response.token)
                }
                .listStyle(.plain)
            } else {
                ContentUnavailableView("No suggestions", systemImage: "text.badge.xmark",
                                       description: Text("EchoSense stays quiet at this position."))
            }
        }
    }

    private var summary: some View {
        let context = model.caretContext
        return VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            (Text(context.before.suffix(40)).foregroundStyle(ColorTokens.Text.secondary)
                + Text("▌").foregroundStyle(ColorTokens.accent)
                + Text(context.after.prefix(20).prefix { $0 != "\n" }).foregroundStyle(ColorTokens.Text.secondary))
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
            if let response = model.response {
                HStack(spacing: SpacingTokens.md) {
                    fact("Clause", "\(response.clause)")
                    fact("Token", response.token.isEmpty ? "none" : "“\(response.token)”")
                    fact("Replaces", "\(response.replacementRange.location)+\(response.replacementRange.length)")
                    fact("Results", "\(response.suggestions.count)")
                    fact("Time", "\(model.elapsedMicroseconds) µs")
                    if response.isMetadataLimited { fact("Metadata", "limited") }
                }
            }
        }
    }

    private func fact(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(name).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            Text(value).font(TypographyTokens.standard.monospacedDigit())
        }
    }
}

struct EchoSenseSuggestionRow: View {
    let rank: Int
    let suggestion: SQLAutoCompletionSuggestion
    let token: String

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Text("\(rank)").font(TypographyTokens.detail.monospacedDigit())
                .foregroundStyle(ColorTokens.Text.tertiary).frame(width: 24, alignment: .trailing)
            Image(systemName: suggestion.kind.iconSystemName)
                .foregroundStyle(ColorTokens.Text.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(suggestion.title).font(.system(.body, design: .monospaced))
                if let detail = suggestion.subtitle ?? suggestion.detail {
                    Text(detail).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            Spacer()
            if let type = suggestion.dataType {
                Text(type).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }
            if let facts = suggestion.columnFacts {
                if facts.isPrimaryKey { Image(systemName: "key.fill").foregroundStyle(ColorTokens.Text.tertiary) }
                if facts.foreignKeyTarget != nil { Image(systemName: "link").foregroundStyle(ColorTokens.Text.tertiary) }
            }
            Text("p\(suggestion.priority)").font(TypographyTokens.detail.monospacedDigit())
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text(String(describing: suggestion.source))
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
        }
    }
}
