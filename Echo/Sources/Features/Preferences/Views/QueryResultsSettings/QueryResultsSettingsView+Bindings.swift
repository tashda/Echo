import SwiftUI
import EchoSense

extension QueryResultsSettingsView {
    var displayModeBinding: Binding<ForeignKeyDisplayMode> {
        Binding(
            get: { projectStore.globalSettings.foreignKeyDisplayMode },
            set: { newValue in
                guard projectStore.globalSettings.foreignKeyDisplayMode != newValue else { return }
                var settings = projectStore.globalSettings
                settings.foreignKeyDisplayMode = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var inspectorBehaviorBinding: Binding<ForeignKeyInspectorBehavior> {
        Binding(
            get: { projectStore.globalSettings.foreignKeyInspectorBehavior },
            set: { newValue in
                guard projectStore.globalSettings.foreignKeyInspectorBehavior != newValue else { return }
                var settings = projectStore.globalSettings
                settings.foreignKeyInspectorBehavior = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var includeRelatedBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.foreignKeyIncludeRelated },
            set: { newValue in
                guard projectStore.globalSettings.foreignKeyIncludeRelated != newValue else { return }
                var settings = projectStore.globalSettings
                settings.foreignKeyIncludeRelated = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var initialRowLimitBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultsInitialRowLimit },
            set: { newValue in
                let clamped = max(100, min(newValue, 100_000))
                guard projectStore.globalSettings.resultsInitialRowLimit != clamped else { return }
                var settings = projectStore.globalSettings
                settings.resultsInitialRowLimit = clamped
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var previewBatchSizeBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultsPreviewBatchSize },
            set: { newValue in
                let clamped = max(100, min(newValue, 100_000))
                guard projectStore.globalSettings.resultsPreviewBatchSize != clamped else { return }
                var settings = projectStore.globalSettings
                settings.resultsPreviewBatchSize = clamped
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var backgroundStreamingThresholdBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultsBackgroundStreamingThreshold },
            set: { newValue in
                let clamped = max(100, min(newValue, 1_000_000))
                guard projectStore.globalSettings.resultsBackgroundStreamingThreshold != clamped else { return }
                var settings = projectStore.globalSettings
                settings.resultsBackgroundStreamingThreshold = clamped
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var backgroundFetchSizeBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultsStreamingFetchSize },
            set: { newValue in
                let clamped = max(128, min(newValue, 16_384))
                guard projectStore.globalSettings.resultsStreamingFetchSize != clamped else { return }
                var settings = projectStore.globalSettings
                settings.resultsStreamingFetchSize = clamped
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var streamingModeBinding: Binding<ResultStreamingExecutionMode> {
        Binding(
            get: { projectStore.globalSettings.resultsStreamingMode },
            set: { newValue in
                guard projectStore.globalSettings.resultsStreamingMode != newValue else { return }
                var settings = projectStore.globalSettings
                settings.resultsStreamingMode = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var fetchRampMultiplierBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultsStreamingFetchRampMultiplier },
            set: { newValue in
                let clamped = max(1, min(newValue, 64))
                guard projectStore.globalSettings.resultsStreamingFetchRampMultiplier != clamped else { return }
                var settings = projectStore.globalSettings
                settings.resultsStreamingFetchRampMultiplier = clamped
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var fetchRampMaxBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultsStreamingFetchRampMax },
            set: { newValue in
                let clamped = max(256, min(newValue, 1_048_576))
                guard projectStore.globalSettings.resultsStreamingFetchRampMax != clamped else { return }
                var settings = projectStore.globalSettings
                settings.resultsStreamingFetchRampMax = clamped
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var autoOpenInspectorBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.autoOpenInspectorOnSelection },
            set: { newValue in
                guard projectStore.globalSettings.autoOpenInspectorOnSelection != newValue else { return }
                var settings = projectStore.globalSettings
                settings.autoOpenInspectorOnSelection = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

}
