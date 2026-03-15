import SwiftUI

extension EchoSenseSettingsView {
    var suggestKeywordsBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.editorSuggestKeywords },
            set: { newValue in
                guard projectStore.globalSettings.editorSuggestKeywords != newValue else { return }
                var settings = projectStore.globalSettings
                settings.editorSuggestKeywords = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var inlineKeywordPreviewBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.editorEnableInlineSuggestions },
            set: { newValue in
                guard projectStore.globalSettings.editorEnableInlineSuggestions != newValue else { return }
                var settings = projectStore.globalSettings
                settings.editorEnableInlineSuggestions = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var suggestFunctionsBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.editorSuggestFunctions },
            set: { newValue in
                guard projectStore.globalSettings.editorSuggestFunctions != newValue else { return }
                var settings = projectStore.globalSettings
                settings.editorSuggestFunctions = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var suggestSnippetsBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.editorSuggestSnippets },
            set: { newValue in
                guard projectStore.globalSettings.editorSuggestSnippets != newValue else { return }
                var settings = projectStore.globalSettings
                settings.editorSuggestSnippets = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

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

    var suggestHistoryBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.editorSuggestHistory },
            set: { newValue in
                guard projectStore.globalSettings.editorSuggestHistory != newValue else { return }
                var settings = projectStore.globalSettings
                settings.editorSuggestHistory = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var suggestJoinsBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.editorSuggestJoins },
            set: { newValue in
                guard projectStore.globalSettings.editorSuggestJoins != newValue else { return }
                var settings = projectStore.globalSettings
                settings.editorSuggestJoins = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var aggressivenessBinding: Binding<SQLCompletionAggressiveness> {
        Binding(
            get: { projectStore.globalSettings.editorCompletionAggressiveness },
            set: { newValue in
                guard projectStore.globalSettings.editorCompletionAggressiveness != newValue else { return }
                var settings = projectStore.globalSettings
                settings.editorCompletionAggressiveness = newValue
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

    var commandTriggerBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.editorAllowCommandPeriodTrigger },
            set: { newValue in
                guard projectStore.globalSettings.editorAllowCommandPeriodTrigger != newValue else { return }
                var settings = projectStore.globalSettings
                settings.editorAllowCommandPeriodTrigger = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var controlTriggerBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.editorAllowControlSpaceTrigger },
            set: { newValue in
                guard projectStore.globalSettings.editorAllowControlSpaceTrigger != newValue else { return }
                var settings = projectStore.globalSettings
                settings.editorAllowControlSpaceTrigger = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var dismissalHint: String {
        let triggers: [String] = [
            appState.sqlEditorDisplay.allowCommandPeriodTrigger ? "\u{2318} + ." : nil,
            appState.sqlEditorDisplay.allowControlSpaceTrigger ? "Ctrl + Space" : nil
        ].compactMap { $0 }

        let triggerText: String
        switch triggers.count {
        case 0:
            triggerText = "the manual trigger"
        case 1:
            triggerText = triggers[0]
        default:
            let head = triggers.dropLast().joined(separator: ", ")
            triggerText = head + " or " + (triggers.last ?? "")
        }

        let suffix = appState.sqlEditorDisplay.autoCompletionEnabled ? "" : " EchoSense stays off until you manually request it."
        return "Dismiss the popover to suspend automatic suggestions temporarily. Use \(triggerText) to bring them back instantly.\(suffix)"
    }
}
