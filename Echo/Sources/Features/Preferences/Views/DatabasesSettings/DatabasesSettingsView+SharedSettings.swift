import SwiftUI

extension DatabasesSettingsView {

    /// Shared execution and ingestion defaults that apply across all engines.
    @ViewBuilder
    var sharedSettings: some View {
        Section {
            StreamingPresetPickerControl(
                title: "Initial rows to display",
                value: initialRowLimitBinding,
                description: "Controls how many rows Echo renders immediately before handing off larger work.",
                presets: streamingRowPresets,
                range: 100...100_000,
                formatter: formatRowCount,
                defaultValue: ResultStreamingDefaults.initialRows
            )

            // Round 21, timeouts (TW2, TD2): the default for every connection; each can override it.
            PropertyRow(
                title: "Query time limit",
                info: "Stops a statement that runs longer than this, for every connection that doesn't set its own. 0 means no limit, like psql and pgAdmin."
            ) {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", value: binding(for: \.queryTimeLimitSeconds), format: .number.grouping(.never), prompt: Text("0"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("seconds")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

            HStack {
                Spacer()
                Button("Revert to Default") {
                    var updated = settings
                    updated.resultsInitialRowLimit = ResultStreamingDefaults.initialRows
                    Task { try? await projectStore.updateGlobalSettings(updated) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(sharedExecutionSettingsAreDefault)
            }
        } header: {
            Text("Execution & Ingestion")
        } footer: {
            Text("These defaults shape how Echo ingests large result sets before any engine-specific overrides are applied.")
        }
    }

    var sharedExecutionSettingsAreDefault: Bool {
        settings.resultsInitialRowLimit == ResultStreamingDefaults.initialRows
    }
}
