import SwiftUI

extension EchoSenseSettingsView {
    var qualifyTablesBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.editorQualifyTableCompletions },
            set: { newValue in
                guard projectStore.globalSettings.editorQualifyTableCompletions != newValue else { return }
                var settings = projectStore.globalSettings
                settings.editorQualifyTableCompletions = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var showSystemSchemasBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.editorShowSystemSchemas },
            set: { newValue in
                guard projectStore.globalSettings.editorShowSystemSchemas != newValue else { return }
                var settings = projectStore.globalSettings
                settings.editorShowSystemSchemas = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var liveValidationBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.editorEnableLiveValidation },
            set: { newValue in
                guard projectStore.globalSettings.editorEnableLiveValidation != newValue else { return }
                var settings = projectStore.globalSettings
                settings.editorEnableLiveValidation = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }
}
