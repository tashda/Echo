import SwiftUI
import Foundation
import EchoSense

extension AutocompleteInspectorRootView {

    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Autocomplete Management")
                    .font(.title2.weight(.semibold))
                Text("Type queries to inspect suppression decisions and tweak rule documentation.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let summary = activeConnectionSummary {
                    Text("Active connection: \(summary)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                VStack(alignment: .leading, spacing: 12) {
                    Text("Latest Trace")
                        .font(.headline)
                    if !trace.metadataItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(trace.metadataItems, id: \.0) { key, value in
                                HStack {
                                    Text(key)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 12)
                                    Text(value)
                                        .font(.footnote)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .padding(SpacingTokens.sm)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    if trace.stepItems.isEmpty {
                        Text("No rule steps recorded.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(trace.stepItems) { step in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(step.title)
                                        .font(.subheadline.weight(.medium))
                                    ForEach(step.details, id: \.self) { detail in
                                        Text(detail)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(SpacingTokens.xs2)
                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }

                    if let outcome = traceOutcomeDescription(trace.outcome) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Outcome")
                                .font(.subheadline.weight(.medium))
                            Text(outcome.title)
                                .font(.callout.weight(.semibold))
                            ForEach(outcome.details, id: \.self) { line in
                                Text(line)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(SpacingTokens.sm)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trace")
                        .font(.headline)
                    Text("Start typing in the editor to capture the rule evaluation flow. The trace lists each decision taken by the suppression heuristics.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Rule Definitions")
                .font(.headline)
            Text("Add notes or reminders for each heuristic. Notes are stored locally and help keep future tweaks aligned.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(SQLAutocompleteRuleDefinition.core) { definition in
                RuleDefinitionRow(definition: definition)
                if definition.id != SQLAutocompleteRuleDefinition.core.last?.id {
                    Divider()
                }
            }
        }
    }
}
