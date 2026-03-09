import SwiftUI
import EchoSense

extension QueryResultsSettingsView {
    var mssqlModeBinding: Binding<ResultStreamingExecutionMode> {
        Binding(
            get: { projectStore.globalSettings.mssqlStreamingMode },
            set: { newValue in
                guard projectStore.globalSettings.mssqlStreamingMode != newValue else { return }
                var settings = projectStore.globalSettings
                settings.mssqlStreamingMode = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var mysqlModeBinding: Binding<ResultStreamingExecutionMode> {
        Binding(
            get: { projectStore.globalSettings.mysqlStreamingMode },
            set: { newValue in
                guard projectStore.globalSettings.mysqlStreamingMode != newValue else { return }
                var settings = projectStore.globalSettings
                settings.mysqlStreamingMode = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var sqliteModeBinding: Binding<ResultStreamingExecutionMode> {
        Binding(
            get: { projectStore.globalSettings.sqliteStreamingMode },
            set: { newValue in
                guard projectStore.globalSettings.sqliteStreamingMode != newValue else { return }
                var settings = projectStore.globalSettings
                settings.sqliteStreamingMode = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var cursorLimitThresholdBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultsCursorStreamingLimitThreshold },
            set: { newValue in
                let clamped = max(0, min(newValue, 100_000))
                guard projectStore.globalSettings.resultsCursorStreamingLimitThreshold != clamped else { return }
                var settings = projectStore.globalSettings
                settings.resultsCursorStreamingLimitThreshold = clamped
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var selectedDisplayMode: ForeignKeyDisplayMode { displayModeBinding.wrappedValue }
    var selectedBehavior: ForeignKeyInspectorBehavior { inspectorBehaviorBinding.wrappedValue }

    var streamingSettingsAreDefault: Bool {
        let settings = projectStore.globalSettings
        return settings.resultsInitialRowLimit == ResultStreamingDefaults.initialRows &&
        settings.resultsPreviewBatchSize == ResultStreamingDefaults.previewBatch &&
        settings.resultsBackgroundStreamingThreshold == ResultStreamingDefaults.backgroundThreshold &&
        settings.resultsStreamingFetchSize == ResultStreamingDefaults.fetchSize &&
        settings.resultsStreamingFetchRampMultiplier == ResultStreamingDefaults.fetchRampMultiplier &&
        settings.resultsStreamingFetchRampMax == ResultStreamingDefaults.fetchRampMax &&
        settings.resultsUseCursorStreaming == ResultStreamingDefaults.useCursor &&
        settings.resultsCursorStreamingLimitThreshold == ResultStreamingDefaults.cursorLimitThreshold
    }

    func displayName(for mode: ForeignKeyDisplayMode) -> String {
        switch mode {
        case .showInspector: return "Open in Inspector"
        case .showIcon: return "Show Cell Icon"
        case .disabled: return "Do Nothing"
        }
    }

    func displayDescription(for mode: ForeignKeyDisplayMode) -> String {
        switch mode {
        case .showInspector: return "Selecting a foreign key cell immediately loads the referenced record."
        case .showIcon: return "Foreign key cells display an inline action icon."
        case .disabled: return "Foreign key metadata is ignored."
        }
    }

    func behaviorDisplayName(for behavior: ForeignKeyInspectorBehavior) -> String {
        switch behavior {
        case .respectInspectorVisibility: return "Use Current Inspector State"
        case .autoOpenAndClose: return "Auto Open & Close"
        }
    }

    func behaviorDescription(for behavior: ForeignKeyInspectorBehavior) -> String {
        switch behavior {
        case .respectInspectorVisibility: return "Only populate the inspector when it is already visible."
        case .autoOpenAndClose: return "Automatically open/close the inspector based on selection."
        }
    }

    func formatMultiplier(_ value: Int) -> String { "\(value)x" }
    func formatRowCount(_ value: Int) -> String { value.formatted() }
}
