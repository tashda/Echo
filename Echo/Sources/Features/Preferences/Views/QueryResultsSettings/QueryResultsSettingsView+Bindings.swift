import SwiftUI

extension QueryResultsSettingsView {

    // MARK: - Computed State

    var selectedDisplayMode: ForeignKeyDisplayMode { displayModeBinding.wrappedValue }
    var selectedBehavior: ForeignKeyInspectorBehavior { inspectorBehaviorBinding.wrappedValue }

    // MARK: - Bindings

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

    // MARK: - Display Helpers

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
}
