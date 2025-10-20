import SwiftUI

struct EchoSenseSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var activeInfoTopic: InfoTopic?

    private var suggestKeywordsBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorSuggestKeywords },
            set: { newValue in
                guard appModel.globalSettings.editorSuggestKeywords != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorSuggestKeywords = newValue } }
            }
        )
    }

    private var inlineKeywordPreviewBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorEnableInlineSuggestions },
            set: { newValue in
                guard appModel.globalSettings.editorEnableInlineSuggestions != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorEnableInlineSuggestions = newValue } }
            }
        )
    }

    private var suggestFunctionsBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorSuggestFunctions },
            set: { newValue in
                guard appModel.globalSettings.editorSuggestFunctions != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorSuggestFunctions = newValue } }
            }
        )
    }

    private var suggestSnippetsBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorSuggestSnippets },
            set: { newValue in
                guard appModel.globalSettings.editorSuggestSnippets != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorSuggestSnippets = newValue } }
            }
        )
    }

    private var qualifyTablesBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorQualifyTableCompletions },
            set: { newValue in
                guard appModel.globalSettings.editorQualifyTableCompletions != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorQualifyTableCompletions = newValue } }
            }
        )
    }

    private var suggestHistoryBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorSuggestHistory },
            set: { newValue in
                guard appModel.globalSettings.editorSuggestHistory != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorSuggestHistory = newValue } }
            }
        )
    }

    private var suggestJoinsBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorSuggestJoins },
            set: { newValue in
                guard appModel.globalSettings.editorSuggestJoins != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorSuggestJoins = newValue } }
            }
        )
    }

    private var aggressivenessBinding: Binding<SQLCompletionAggressiveness> {
        Binding(
            get: { appModel.globalSettings.editorCompletionAggressiveness },
            set: { newValue in
                guard appModel.globalSettings.editorCompletionAggressiveness != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorCompletionAggressiveness = newValue } }
            }
        )
    }

    private var showSystemSchemasBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorShowSystemSchemas },
            set: { newValue in
                guard appModel.globalSettings.editorShowSystemSchemas != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorShowSystemSchemas = newValue } }
            }
        )
    }

    private var commandTriggerBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorAllowCommandPeriodTrigger },
            set: { newValue in
                guard appModel.globalSettings.editorAllowCommandPeriodTrigger != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorAllowCommandPeriodTrigger = newValue } }
            }
        )
    }

    private var controlTriggerBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorAllowControlSpaceTrigger },
            set: { newValue in
                guard appModel.globalSettings.editorAllowControlSpaceTrigger != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorAllowControlSpaceTrigger = newValue } }
            }
        )
    }

    private var dismissalHint: String {
        let triggers: [String] = [
            appState.sqlEditorDisplay.allowCommandPeriodTrigger ? "⌘ + ." : nil,
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
            triggerText = head + " or " + triggers.last!
        }

        let suffix = appState.sqlEditorDisplay.autoCompletionEnabled ? "" : " EchoSense stays off until you manually request it."
        return "Dismiss the popover to suspend automatic suggestions temporarily. Use \(triggerText) to bring them back instantly.\(suffix)"
    }

    var body: some View {
        Form {
            Section("Suggestions") {
                ToggleRow(
                    title: "Keywords",
                    subtitle: "Add SQL keywords (SELECT, WHERE) in the suggestion list.",
                    isOn: suggestKeywordsBinding,
                    infoAction: { showInfo(.keywords) }
                )
                ToggleRow(
                    title: "Inline keyword preview",
                    subtitle: "Show a dimmed keyword directly in the editor when a matching clause is expected.",
                    isOn: inlineKeywordPreviewBinding,
                    infoAction: { showInfo(.inlineKeywords) }
                )
                .disabled(!appState.sqlEditorDisplay.autoCompletionEnabled)
                ToggleRow(
                    title: "Functions",
                    subtitle: "Include built-in and database-specific functions in suggestions.",
                    isOn: suggestFunctionsBinding,
                    infoAction: { showInfo(.functions) }
                )
                ToggleRow(
                    title: "Snippets",
                    subtitle: "Offer templated snippets with tab stops for common patterns.",
                    isOn: suggestSnippetsBinding,
                    infoAction: { showInfo(.snippets) }
                )
                ToggleRow(
                    title: "Join Helpers",
                    subtitle: "Suggest ON clauses derived from foreign keys or accepted joins.",
                    isOn: suggestJoinsBinding,
                    infoAction: { showInfo(.joins) }
                )
                ToggleRow(
                    title: "History Boosting",
                    subtitle: "Favor tables, columns, and joins you accepted recently.",
                    isOn: suggestHistoryBinding,
                    infoAction: { showInfo(.history) }
                )
            }

            Section("Insertion") {
                ToggleRow(
                    title: "Qualify table completions",
                    subtitle: "Insert schema-qualified names when the engine knows the schema.",
                    isOn: qualifyTablesBinding,
                    infoAction: { showInfo(.qualifiedTables) }
                )
                ToggleRow(
                    title: "Show system schemas",
                    subtitle: "Reveal pg_catalog, information_schema, and other system objects.",
                    isOn: showSystemSchemasBinding,
                    infoAction: { showInfo(.systemSchemas) }
                )
            }

            Section("Behaviour") {
                Picker("Suggestion aggressiveness", selection: aggressivenessBinding) {
                    ForEach(SQLCompletionAggressiveness.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)

                ToggleRow(
                    title: "Enable Command + Period",
                    subtitle: "Keep ⌘ + . available after dismissing the EchoSense popover.",
                    isOn: commandTriggerBinding,
                    infoAction: { showInfo(.commandTrigger) }
                )
                ToggleRow(
                    title: "Enable Control + Space",
                    subtitle: "Keep Ctrl + Space available as an alternative manual trigger.",
                    isOn: controlTriggerBinding,
                    infoAction: { showInfo(.controlTrigger) }
                )
            }

            Section("Dismissal") {
                Text(dismissalHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(themeManager.surfaceBackgroundColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .popover(item: $activeInfoTopic, arrowEdge: .top) { topic in
            InfoPopover(topic: topic)
        }
    }

    private func showInfo(_ topic: InfoTopic) {
        activeInfoTopic = topic
    }
}

private enum InfoTopic: String, Identifiable, CaseIterable {
    case keywords
    case inlineKeywords
    case functions
    case snippets
    case joins
    case qualifiedTables
    case history
    case aggressiveness
    case systemSchemas
    case commandTrigger
    case controlTrigger

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keywords: return "Keyword Suggestions"
        case .inlineKeywords: return "Inline Keyword Preview"
        case .functions: return "Function Suggestions"
        case .snippets: return "Snippet Templates"
        case .joins: return "Join Helpers"
        case .qualifiedTables: return "Schema-qualified Insertion"
        case .history: return "Recent Selections"
        case .aggressiveness: return "Suggestion Aggressiveness"
        case .systemSchemas: return "System Schemas"
        case .commandTrigger: return "Command + Period"
        case .controlTrigger: return "Control + Space"
        }
    }

    var message: String {
        switch self {
        case .keywords:
            return "When enabled, the EchoSense popover lists SQL keywords that match the current clause. Turning this off hides keyword entries, but it will not remove snippets or objects that explicitly match what you type."
        case .inlineKeywords:
            return "Shows the remainder of the next SQL keyword as faint inline text (for example FROM after SELECT *). Disabling this keeps keyword rows in the popover intact but removes the ghosted preview inside the editor."
        case .functions:
            return "Shows built-in and database-specific functions ranked by context. Disabling this leaves typed function names untouched and does not affect user-defined functions you type manually."
        case .snippets:
            return "Provides templated completions (for example CASE, JSON helpers) with tab-stop placeholders. When disabled, no snippet rows appear, but regular keywords and objects remain available."
        case .joins:
            return "Offers ON-clause suggestions derived from foreign keys and recent join history. Turning it off keeps JOIN keywords and table suggestions, but removes the one-click join conditions."
        case .qualifiedTables:
            return "Automatically inserts schema-qualified names (schema.table) when a completion knows the schema. Existing text is never rewritten, and column completions keep their current behaviour."
        case .history:
            return "Remember tables, columns, and joins you accept so the engine can boost them later. History stays on your Mac and does not sync or leave the application."
        case .aggressiveness:
            return "Focused shows only clause-relevant entries, Balanced keeps a mix with light fallbacks, and Eager keeps the full list. Switch modes depending on whether you prefer concise or generous suggestions."
        case .systemSchemas:
            return "System schemas such as pg_catalog or information_schema contain internal objects. Enable this when you want to browse them in EchoSense; otherwise they stay hidden to reduce noise."
        case .commandTrigger:
            return "Keeps the ⌘ + . shortcut available as a manual EchoSense trigger even after you dismiss the popover. Turn it off if you rely on ⌘ + . for another workflow."
        case .controlTrigger:
            return "Keeps Ctrl + Space available as an alternative manual trigger for EchoSense, mirroring common editor behaviour. Disable it if Ctrl + Space is bound to another action on your system."
        }
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    let infoAction: () -> Void

    var body: some View {
        HStack(alignment: subtitle == nil ? .center : .top, spacing: 12) {
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            Button(action: infoAction) {
                Image(systemName: "info.circle")
                    .font(.system(size: 15, weight: .medium))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More information about \(title)")
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(Text(title))
        }
        .padding(.vertical, subtitle == nil ? 4 : 6)
    }
}

private struct InfoPopover: View {
    let topic: InfoTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(topic.title)
                .font(.headline)
            Text(topic.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: 320)
    }
}
