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

            StreamingPresetPickerControl(
                title: "Background Streaming Threshold",
                value: backgroundStreamingThresholdBinding,
                description: "After this many rows, Echo moves ingestion work to a background path.",
                presets: streamingThresholdPresets,
                range: 100...1_000_000,
                formatter: formatRowCount,
                defaultValue: ResultStreamingDefaults.backgroundThreshold
            )

            StreamingPresetPickerControl(
                title: "Background Fetch Batch Size",
                value: backgroundFetchSizeBinding,
                description: "Controls how many rows Echo requests in each background fetch.",
                presets: streamingFetchPresets,
                range: 128...16_384,
                formatter: formatRowCount,
                defaultValue: ResultStreamingDefaults.fetchSize
            )

            StreamingPresetPickerControl(
                title: "Fetch Ramp Multiplier",
                value: fetchRampMultiplierBinding,
                description: "Determines how aggressively Echo expands fetch sizes after initial batches.",
                presets: streamingFetchRampMultiplierPresets,
                range: 1...64,
                formatter: formatMultiplier,
                defaultValue: ResultStreamingDefaults.fetchRampMultiplier
            )

            StreamingPresetPickerControl(
                title: "Fetch Ramp Maximum",
                value: fetchRampMaxBinding,
                description: "Caps the largest background fetch Echo will request.",
                presets: streamingFetchRampMaxPresets,
                range: 256...1_048_576,
                formatter: formatRowCount,
                defaultValue: ResultStreamingDefaults.fetchRampMax
            )

            HStack {
                Spacer()
                Button("Revert to Default") {
                    var updated = settings
                    updated.resultsInitialRowLimit = ResultStreamingDefaults.initialRows
                    updated.resultsPreviewBatchSize = ResultStreamingDefaults.previewBatch
                    updated.resultsBackgroundStreamingThreshold = ResultStreamingDefaults.backgroundThreshold
                    updated.resultsStreamingFetchSize = ResultStreamingDefaults.fetchSize
                    updated.resultsStreamingFetchRampMultiplier = ResultStreamingDefaults.fetchRampMultiplier
                    updated.resultsStreamingFetchRampMax = ResultStreamingDefaults.fetchRampMax
                    updated.resultsUseCursorStreaming = ResultStreamingDefaults.useCursor
                    updated.resultsCursorStreamingLimitThreshold = ResultStreamingDefaults.cursorLimitThreshold
                    Task { try? await projectStore.updateGlobalSettings(updated) }
                }
                .buttonStyle(.bordered)
                .disabled(sharedExecutionSettingsAreDefault)
            }
            .padding(.top, SpacingTokens.xxs2)
        } header: {
            Text("Execution & Ingestion")
        } footer: {
            Text("These defaults shape how Echo ingests large result sets before any engine-specific overrides are applied.")
        }
    }

    var sharedExecutionSettingsAreDefault: Bool {
        settings.resultsInitialRowLimit == ResultStreamingDefaults.initialRows &&
        settings.resultsPreviewBatchSize == ResultStreamingDefaults.previewBatch &&
        settings.resultsBackgroundStreamingThreshold == ResultStreamingDefaults.backgroundThreshold &&
        settings.resultsStreamingFetchSize == ResultStreamingDefaults.fetchSize &&
        settings.resultsStreamingFetchRampMultiplier == ResultStreamingDefaults.fetchRampMultiplier &&
        settings.resultsStreamingFetchRampMax == ResultStreamingDefaults.fetchRampMax &&
        settings.resultsUseCursorStreaming == ResultStreamingDefaults.useCursor &&
        settings.resultsCursorStreamingLimitThreshold == ResultStreamingDefaults.cursorLimitThreshold
    }
}
