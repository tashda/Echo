import SwiftUI

extension QueryResultsSettingsView {

    // MARK: - Bindings

    var showRowNumbersBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.resultsShowRowNumbers },
            set: { newValue in
                guard projectStore.globalSettings.resultsShowRowNumbers != newValue else { return }
                var settings = projectStore.globalSettings
                settings.resultsShowRowNumbers = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var alternateRowShadingBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.resultsAlternateRowShading },
            set: { newValue in
                guard projectStore.globalSettings.resultsAlternateRowShading != newValue else { return }
                var settings = projectStore.globalSettings
                settings.resultsAlternateRowShading = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var showForeignKeysInInspectorBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.showForeignKeysInInspector },
            set: { newValue in
                guard projectStore.globalSettings.showForeignKeysInInspector != newValue else { return }
                var settings = projectStore.globalSettings
                settings.showForeignKeysInInspector = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var showJsonInInspectorBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.showJsonInInspector },
            set: { newValue in
                guard projectStore.globalSettings.showJsonInInspector != newValue else { return }
                var settings = projectStore.globalSettings
                settings.showJsonInInspector = newValue
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
