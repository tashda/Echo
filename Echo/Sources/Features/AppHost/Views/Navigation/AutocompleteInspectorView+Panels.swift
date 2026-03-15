import SwiftUI
import Foundation
import EchoSense

extension AutocompleteInspectorRootView {

    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                Text("Autocomplete Management")
                    .font(TypographyTokens.title2.weight(.semibold))
                Text("Type queries to inspect suppression decisions and tweak rule documentation.")
                    .font(TypographyTokens.subheadline)
                    .foregroundStyle(ColorTokens.Text.secondary)
                if let summary = activeConnectionSummary {
                    Text("Active connection: \(summary)")
                        .font(TypographyTokens.footnote)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            Spacer()
            Toggle(isOn: traceFrozenBinding) {
                Label("Freeze Trace", systemImage: isTraceFrozenValue ? "pause.fill" : "play.fill")
                    .labelStyle(.iconOnly)
                    .accessibilityLabel(isTraceFrozenValue ? "Resume Trace Updates" : "Freeze Trace Updates")
            }
            .toggleStyle(.switch)
            .help("When enabled, the current trace stays visible while you experiment in the editor.")
        }
    }

    var tracePanel: some View {
        Group {
            if let trace = latestTraceValue {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Text("Latest Trace")
                        .font(TypographyTokens.headline)
                    if !trace.metadataItems.isEmpty {
                        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                            ForEach(trace.metadataItems, id: \.0) { key, value in
                                HStack {
                                    Text(key)
                                        .font(TypographyTokens.footnote.weight(.semibold))
                                        .foregroundStyle(ColorTokens.Text.secondary)
                                    Spacer(minLength: SpacingTokens.sm)
                                    Text(value)
                                        .font(TypographyTokens.footnote)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .padding(SpacingTokens.sm)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    if trace.stepItems.isEmpty {
                        Text("No rule steps recorded.")
                            .font(TypographyTokens.footnote)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: SpacingTokens.xs2) {
                            ForEach(trace.stepItems) { step in
                                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                                    Text(step.title)
                                        .font(TypographyTokens.subheadline.weight(.medium))
                                    ForEach(step.details, id: \.self) { detail in
                                        Text(detail)
                                            .font(TypographyTokens.footnote)
                                            .foregroundStyle(ColorTokens.Text.secondary)
                                    }
                                }
                                .padding(SpacingTokens.xs2)
                                .background(ColorTokens.Text.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }

                    if let outcome = traceOutcomeDescription(trace.outcome) {
                        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                            Text("Outcome")
                                .font(TypographyTokens.subheadline.weight(.medium))
                            Text(outcome.title)
                                .font(TypographyTokens.callout.weight(.semibold))
                            ForEach(outcome.details, id: \.self) { line in
                                Text(line)
                                    .font(TypographyTokens.footnote)
                                    .foregroundStyle(ColorTokens.Text.secondary)
                            }
                        }
                        .padding(SpacingTokens.sm)
                        .background(ColorTokens.Text.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("Trace")
                        .font(TypographyTokens.headline)
                    Text("Start typing in the editor to capture the rule evaluation flow. The trace lists each decision taken by the suppression heuristics.")
                        .font(TypographyTokens.footnote)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }

    func traceOutcomeDescription(_ outcome: SQLAutocompleteTrace.Outcome?) -> (title: String, details: [String])? {
        guard let outcome else { return nil }
        switch outcome {
        case let .produced(summary):
            let diagnostics = summary.diagnostics.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }
            return ("Suppression Applied (\(summary.canonicalText))", ["Has follow-ups: \(summary.hasFollowUps ? "Yes" : "No")"] + diagnostics)
        case let .skipped(reason):
            return ("Suppression Skipped", [reason])
        }
    }

    var definitionsPanel: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Rule Definitions")
                .font(TypographyTokens.headline)
            Text("Add notes or reminders for each heuristic. Notes are stored locally and help keep future tweaks aligned.")
                .font(TypographyTokens.footnote)
                .foregroundStyle(ColorTokens.Text.secondary)

            ForEach(SQLAutocompleteRuleDefinition.core) { definition in
                RuleDefinitionRow(definition: definition)
                if definition.id != SQLAutocompleteRuleDefinition.core.last?.id {
                    Divider()
                }
            }
        }
    }
}
