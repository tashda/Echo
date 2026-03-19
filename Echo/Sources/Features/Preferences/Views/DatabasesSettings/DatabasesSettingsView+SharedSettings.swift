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

            StreamingPresetPickerControl(
                title: "Data Preview Batch Size",
                value: previewBatchSizeBinding,
                description: "Used when opening previews from the sidebar or object browser.",
                presets: streamingRowPresets,
                range: 100...100_000,
                formatter: formatRowCount,
                defaultValue: ResultStreamingDefaults.previewBatch
            )

            HStack {
                Spacer()
                Button("Revert to Default") {
                    var updated = settings
                    updated.resultsInitialRowLimit = ResultStreamingDefaults.initialRows
                    updated.resultsPreviewBatchSize = ResultStreamingDefaults.previewBatch
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
        settings.resultsInitialRowLimit == ResultStreamingDefaults.initialRows &&
        settings.resultsPreviewBatchSize == ResultStreamingDefaults.previewBatch
    }
}
